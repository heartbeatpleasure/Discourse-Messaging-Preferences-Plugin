# frozen_string_literal: true

module ::MessagingPreferences
  class UserArchiveExport
    def self.data_present?(user)
      ::UserCustomField.where(
        user_id: user.id,
        name: ::MessagingPreferences::FIELD_NAMES,
      ).exists? || acknowledgement_scope_for(user).exists? || event_scope_for(user).exists?
    end

    def self.payload(user)
      new(user).payload
    end

    def initialize(user)
      @user = user
    end

    def payload
      snapshot = ::MessagingPreferences::PreferenceSnapshot.new(@user)

      {
        generated_at: Time.zone.now.iso8601(6),
        preferences: {
          works_well: snapshot.works_well,
          please_avoid: snapshot.please_avoid,
          has_preferences: snapshot.present?,
          preferences_digest: snapshot.digest,
          updated_at: preferences_updated_at&.iso8601(6),
        },
        acknowledgements_made: acknowledgements_made,
        acknowledgements_received: acknowledgements_received,
        activity_events: activity_events,
      }
    end

    private

    def self.acknowledgement_scope_for(user)
      return ::MessagingPreferences::Acknowledgement.none if !::MessagingPreferences::Acknowledgement.table_ready?

      ::MessagingPreferences::Acknowledgement.where(
        "viewer_user_id = :user_id OR target_user_id = :user_id",
        user_id: user.id,
      )
    end

    def self.event_scope_for(user)
      return ::MessagingPreferences::Event.none if !::MessagingPreferences::Event.table_ready?

      ::MessagingPreferences::Event.where(
        "actor_user_id = :user_id OR target_user_id = :user_id",
        user_id: user.id,
      )
    end

    def preferences_updated_at
      ::UserCustomField
        .where(user_id: @user.id, name: ::MessagingPreferences::FIELD_NAMES)
        .maximum(:updated_at)
    end

    def acknowledgements_made
      return [] if !::MessagingPreferences::Acknowledgement.table_ready?

      rows =
        ::MessagingPreferences::Acknowledgement
          .where(viewer_user_id: @user.id)
          .order(acknowledged_at: :asc)
          .pluck(:target_user_id, :preferences_digest, :acknowledged_at)

      users = users_by_id(rows.map(&:first))

      rows.filter_map do |target_user_id, digest, acknowledged_at|
        target = users[target_user_id]
        next if target.blank?

        {
          member_username: target.username,
          acknowledged_at: acknowledged_at&.iso8601(6),
          current: current_digest_for(target) == digest,
        }
      end
    end

    def acknowledgements_received
      return [] if !::MessagingPreferences::Acknowledgement.table_ready?

      rows =
        ::MessagingPreferences::Acknowledgement
          .where(target_user_id: @user.id)
          .order(acknowledged_at: :asc)
          .pluck(:viewer_user_id, :preferences_digest, :acknowledged_at)

      users = users_by_id(rows.map(&:first))
      current_digest = ::MessagingPreferences::PreferenceSnapshot.new(@user).digest

      rows.filter_map do |viewer_user_id, digest, acknowledged_at|
        viewer = users[viewer_user_id]
        next if viewer.blank?

        {
          member_username: viewer.username,
          acknowledged_at: acknowledged_at&.iso8601(6),
          current: current_digest.present? && current_digest == digest,
        }
      end
    end

    def activity_events
      return [] if !::MessagingPreferences::Event.table_ready?

      records =
        ::MessagingPreferences::Event
          .where("actor_user_id = :id OR target_user_id = :id", id: @user.id)
          .order(occurred_at: :asc)
          .to_a

      counterpart_ids =
        records.filter_map do |event|
          next if event.event_type != ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE

          event.actor_user_id == @user.id ? event.target_user_id : event.actor_user_id
        end
      users = users_by_id(counterpart_ids)

      records.map do |event|
        actor_is_user = event.actor_user_id == @user.id
        counterpart_id = actor_is_user ? event.target_user_id : event.actor_user_id
        include_counterpart =
          event.event_type == ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE

        {
          event_type: event.event_type,
          role: actor_is_user ? "actor" : "target",
          counterpart_username:
            include_counterpart ? users[counterpart_id]&.username : nil,
          occurred_at: event.occurred_at&.iso8601(6),
        }
      end
    end

    def users_by_id(ids)
      ids = ids.compact.uniq
      return {} if ids.empty?

      ::User.where(id: ids).index_by(&:id)
    end

    def current_digest_for(user)
      ::MessagingPreferences::PreferenceSnapshot.new(user).digest
    end
  end
end

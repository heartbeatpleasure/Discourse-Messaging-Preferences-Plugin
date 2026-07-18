# frozen_string_literal: true

module ::MessagingPreferences
  class AdminActivity
    RECENT_EVENT_LIMIT = 50
    USER_EVENT_LIMIT = 100
    RELATIONSHIP_LIMIT = 100

    class << self
      def payload(user_id: nil)
        states = preference_states
        acknowledgements = acknowledgement_rows

        {
          generated_at: Time.zone.now.iso8601(6),
          tracking_started_at: tracking_started_at,
          summary: summary(states, acknowledgements),
          recent_events: recent_events,
          selected_user: user_id.present? ? user_payload(user_id, states) : nil,
        }
      end

      def search_users(term)
        normalized = term.to_s.strip
        return [] if normalized.length < 2

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(normalized.downcase)}%"

        ::User
          .where(active: true, staged: false)
          .where(
            "username_lower LIKE :pattern OR LOWER(COALESCE(name, '')) LIKE :pattern",
            pattern: pattern,
          )
          .order(:username_lower)
          .limit(20)
          .pluck(:id, :username, :name, :avatar_template)
          .map do |id, username, name, avatar_template|
            { id: id, username: username, name: name, avatar_template: avatar_template }
          end
      end

      private

      def active_user_scope
        ::User.where(active: true, staged: false)
      end

      def preference_states(user_ids = nil)
        scope =
          ::UserCustomField.where(
            name: ::MessagingPreferences::FIELD_NAMES,
            user_id: active_user_scope.select(:id),
          )
        scope = scope.where(user_id: user_ids) if user_ids.present?

        states = Hash.new do |hash, user_id|
          hash[user_id] = {
            works_well: "",
            please_avoid: "",
            updated_at: nil,
          }
        end

        scope
          .order(:id)
          .pluck(:user_id, :name, :value, :updated_at)
          .each do |user_id, name, value, updated_at|
            state = states[user_id]
            normalized = ::MessagingPreferences.normalize_text(value)

            if name == ::MessagingPreferences::WORKS_WELL_FIELD
              state[:works_well] = normalized
            elsif name == ::MessagingPreferences::PLEASE_AVOID_FIELD
              state[:please_avoid] = normalized
            end

            state[:updated_at] = [state[:updated_at], updated_at].compact.max
          end

        states.each_value do |state|
          state[:digest] =
            ::MessagingPreferences::PreferenceSnapshot.digest_for(
              works_well: state[:works_well],
              please_avoid: state[:please_avoid],
            )
          state[:has_preferences] = state[:digest].present?
          state[:works_well_set] = state[:works_well].present?
          state[:please_avoid_set] = state[:please_avoid].present?
        end

        states.select { |_user_id, state| state[:has_preferences] }
      end

      def acknowledgement_rows
        return [] if !::MessagingPreferences::Acknowledgement.table_ready?

        ::MessagingPreferences::Acknowledgement.pluck(
          :viewer_user_id,
          :target_user_id,
          :preferences_digest,
          :acknowledged_at,
        )
      end

      def summary(states, acknowledgements)
        current_acknowledgements =
          acknowledgements.count do |_viewer_id, target_id, digest, _acknowledged_at|
            states.dig(target_id, :digest) == digest
          end

        event_counts = event_counts_by_type
        recent_cutoff = 30.days.ago

        {
          members_with_preferences: states.length,
          members_with_both_fields:
            states.count do |_id, state|
              state[:works_well_set] && state[:please_avoid_set]
            end,
          members_with_works_well_only:
            states.count { |_id, state| state[:works_well_set] && !state[:please_avoid_set] },
          members_with_please_avoid_only:
            states.count { |_id, state| !state[:works_well_set] && state[:please_avoid_set] },
          members_updated_last_30_days:
            states.count do |_id, state|
              state[:updated_at].present? && state[:updated_at] >= recent_cutoff
            end,
          acknowledgement_records: acknowledgements.length,
          current_acknowledgements: current_acknowledgements,
          outdated_acknowledgements: acknowledgements.length - current_acknowledgements,
          distinct_acknowledging_members: acknowledgements.map(&:first).uniq.length,
          distinct_preference_owners_acknowledged:
            acknowledgements.map { |row| row[1] }.uniq.length,
          tracked_preference_changes:
            ::MessagingPreferences::Event::PREFERENCE_EVENT_TYPES.sum do |type|
              event_counts[type].to_i
            end,
          tracked_acknowledgements:
            event_counts[::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE].to_i,
        }
      end

      def event_counts_by_type
        return {} if !::MessagingPreferences::Event.table_ready?

        ::MessagingPreferences::Event.group(:event_type).count
      end

      def tracking_started_at
        return if !::MessagingPreferences::Event.table_ready?

        ::MessagingPreferences::Event.minimum(:occurred_at)&.iso8601(6)
      end

      def recent_events
        return [] if !::MessagingPreferences::Event.table_ready?

        serialize_events(
          ::MessagingPreferences::Event.order(occurred_at: :desc).limit(RECENT_EVENT_LIMIT),
        )
      end

      def user_payload(user_id, states)
        user = active_user_scope.find_by(id: user_id.to_i)
        return if user.blank?

        state = states[user.id] || empty_state
        received = received_acknowledgements(user, states)
        made = made_acknowledgements(user, states)
        events = user_events(user)

        event_counts = user_event_counts(user)
        relationship_counts = current_relationship_counts(user, states)

        {
          user: serialize_user(user),
          current_preferences: {
            has_preferences: state[:has_preferences] == true,
            works_well_set: state[:works_well_set] == true,
            please_avoid_set: state[:please_avoid_set] == true,
            updated_at: state[:updated_at]&.iso8601(6),
          },
          counts: event_counts.merge(relationship_counts),
          acknowledgements_received: received,
          acknowledgements_made: made,
          events: events,
        }
      end

      def empty_state
        {
          has_preferences: false,
          works_well_set: false,
          please_avoid_set: false,
          updated_at: nil,
          digest: nil,
        }
      end

      def received_acknowledgements(user, states)
        return [] if !::MessagingPreferences::Acknowledgement.table_ready?

        rows =
          ::MessagingPreferences::Acknowledgement
            .where(target_user_id: user.id)
            .order(acknowledged_at: :desc)
            .limit(RELATIONSHIP_LIMIT)
            .pluck(:viewer_user_id, :preferences_digest, :acknowledged_at)

        users = users_by_id(rows.map(&:first))
        current_digest = states.dig(user.id, :digest)

        rows.filter_map do |viewer_id, digest, acknowledged_at|
          viewer = users[viewer_id]
          next if viewer.blank?

          {
            user: serialize_user(viewer),
            acknowledged_at: acknowledged_at&.iso8601(6),
            current: current_digest.present? && current_digest == digest,
          }
        end
      end

      def made_acknowledgements(user, states)
        return [] if !::MessagingPreferences::Acknowledgement.table_ready?

        rows =
          ::MessagingPreferences::Acknowledgement
            .where(viewer_user_id: user.id)
            .order(acknowledged_at: :desc)
            .limit(RELATIONSHIP_LIMIT)
            .pluck(:target_user_id, :preferences_digest, :acknowledged_at)

        users = users_by_id(rows.map(&:first))

        rows.filter_map do |target_id, digest, acknowledged_at|
          target = users[target_id]
          next if target.blank?

          {
            user: serialize_user(target),
            acknowledged_at: acknowledged_at&.iso8601(6),
            current:
              states.dig(target_id, :digest).present? &&
                states.dig(target_id, :digest) == digest,
          }
        end
      end


      def current_relationship_counts(user, states)
        return {
          current_acknowledgements_received: 0,
          current_acknowledgements_made: 0,
        } if !::MessagingPreferences::Acknowledgement.table_ready?

        current_digest = states.dig(user.id, :digest)
        received =
          if current_digest.present?
            ::MessagingPreferences::Acknowledgement.where(
              target_user_id: user.id,
              preferences_digest: current_digest,
            ).count
          else
            0
          end

        made =
          ::MessagingPreferences::Acknowledgement
            .where(viewer_user_id: user.id)
            .pluck(:target_user_id, :preferences_digest)
            .count do |target_id, digest|
              states.dig(target_id, :digest).present? &&
                states.dig(target_id, :digest) == digest
            end

        {
          current_acknowledgements_received: received,
          current_acknowledgements_made: made,
        }
      end

      def user_event_counts(user)
        return {
          tracked_preference_changes: 0,
          tracked_acknowledgements_received: 0,
          tracked_acknowledgements_made: 0,
        } if !::MessagingPreferences::Event.table_ready?

        {
          tracked_preference_changes:
            ::MessagingPreferences::Event.where(
              target_user_id: user.id,
              event_type: ::MessagingPreferences::Event::PREFERENCE_EVENT_TYPES,
            ).count,
          tracked_acknowledgements_received:
            ::MessagingPreferences::Event.where(
              target_user_id: user.id,
              event_type: ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE,
            ).count,
          tracked_acknowledgements_made:
            ::MessagingPreferences::Event.where(
              actor_user_id: user.id,
              event_type: ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE,
            ).count,
        }
      end

      def user_events(user)
        return [] if !::MessagingPreferences::Event.table_ready?

        serialize_events(
          ::MessagingPreferences::Event
            .where("actor_user_id = :id OR target_user_id = :id", id: user.id)
            .order(occurred_at: :desc)
            .limit(USER_EVENT_LIMIT),
        )
      end

      def serialize_events(scope)
        records = scope.to_a
        users =
          users_by_id(
            records.flat_map { |event| [event.actor_user_id, event.target_user_id] },
          )

        records.map do |event|
          {
            id: event.id,
            event_type: event.event_type,
            actor_user_id: event.actor_user_id,
            target_user_id: event.target_user_id,
            actor: serialize_user(users[event.actor_user_id]),
            target: serialize_user(users[event.target_user_id]),
            occurred_at: event.occurred_at&.iso8601(6),
          }
        end
      end

      def users_by_id(ids)
        ids = ids.compact.uniq
        return {} if ids.empty?

        ::User.where(id: ids).index_by(&:id)
      end

      def serialize_user(user)
        return if user.blank?

        {
          id: user.id,
          username: user.username,
          name: user.name,
          avatar_template: user.avatar_template,
        }
      end
    end
  end
end

# frozen_string_literal: true

module ::MessagingPreferences
  class EventRecorder
    def self.record_preference_change!(user:, before_snapshot:, after_snapshot:)
      return false if !::MessagingPreferences::Event.table_ready?
      return false if before_snapshot.digest == after_snapshot.digest

      event_type =
        if !before_snapshot.present? && after_snapshot.present?
          "preferences_created"
        elsif before_snapshot.present? && !after_snapshot.present?
          "preferences_cleared"
        else
          "preferences_updated"
        end

      create_event(
        event_type: event_type,
        actor_user_id: user.id,
        target_user_id: user.id,
        preferences_digest: after_snapshot.digest,
      )
    end

    def self.record_admin_preference_clear!(actor:, target:, before_snapshot:)
      return false if !before_snapshot.present?
      return false if !::MessagingPreferences::Event.table_ready?

      create_event(
        event_type: "preferences_admin_cleared",
        actor_user_id: actor.id,
        target_user_id: target.id,
        preferences_digest: nil,
      )
    end

    def self.record_admin_sitewide_cleanup!(actor:)
      return false if !::MessagingPreferences::Event.table_ready?

      create_event(
        event_type: "admin_site_cleanup",
        actor_user_id: actor.id,
        target_user_id: actor.id,
      )
    end

    def self.record_admin_reset_all_acknowledgements!(actor:, removed_count:)
      return false if removed_count.to_i <= 0
      return false if !::MessagingPreferences::Event.table_ready?

      create_event(
        event_type: "admin_reset_all_acks",
        actor_user_id: actor.id,
        target_user_id: actor.id,
      )
    end

    def self.record_admin_reset_member_acknowledgements!(actor:, target:, removed_count:)
      return false if removed_count.to_i <= 0
      return false if !::MessagingPreferences::Event.table_ready?

      create_event(
        event_type: "admin_reset_member_acks",
        actor_user_id: actor.id,
        target_user_id: target.id,
      )
    end

    def self.record_acknowledgement!(viewer:, target:, digest:, already_current:)
      return false if already_current
      return false if !::MessagingPreferences::Event.table_ready?

      create_event(
        event_type: ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE,
        actor_user_id: viewer.id,
        target_user_id: target.id,
        preferences_digest: digest,
      )
    end

    def self.create_event(event_type:, actor_user_id:, target_user_id:, preferences_digest: nil)
      ::MessagingPreferences::Event.create!(
        event_type: event_type,
        actor_user_id: actor_user_id,
        target_user_id: target_user_id,
        preferences_digest: preferences_digest.presence,
        occurred_at: Time.zone.now,
      )
      true
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.warn(
        "[messaging_preferences] activity_event_write_failed event_type=#{event_type} error=#{error.class}",
      )
      false
    end
  end
end

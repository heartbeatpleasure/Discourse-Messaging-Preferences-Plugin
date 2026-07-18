# frozen_string_literal: true

module ::MessagingPreferences
  class Event < ::ActiveRecord::Base
    self.table_name = "messaging_preference_events"

    PREFERENCE_EVENT_TYPES = %w[
      preferences_created
      preferences_updated
      preferences_cleared
      preferences_admin_cleared
    ].freeze
    ACKNOWLEDGEMENT_EVENT_TYPE = "acknowledged"
    SITEWIDE_ADMIN_EVENT_TYPES = %w[
      admin_site_cleanup
      admin_reset_all_acks
    ].freeze
    MEMBER_ADMIN_EVENT_TYPES = %w[
      preferences_admin_cleared
      admin_reset_member_acks
    ].freeze
    ADMIN_EVENT_TYPES =
      (SITEWIDE_ADMIN_EVENT_TYPES + MEMBER_ADMIN_EVENT_TYPES).uniq.freeze
    MEMBER_ACTIVITY_EVENT_TYPES =
      (PREFERENCE_EVENT_TYPES + [ACKNOWLEDGEMENT_EVENT_TYPE]).uniq.freeze
    EVENT_TYPES = (MEMBER_ACTIVITY_EVENT_TYPES + ADMIN_EVENT_TYPES).uniq.freeze

    belongs_to :actor, class_name: "::User", foreign_key: :actor_user_id
    belongs_to :target, class_name: "::User", foreign_key: :target_user_id

    validates :event_type, inclusion: { in: EVENT_TYPES }
    validates :actor_user_id, :target_user_id, :occurred_at, presence: true
    validates :preferences_digest,
              length: { is: 64 },
              allow_blank: true

    def self.table_ready?
      connection.data_source_exists?(table_name)
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      false
    end
  end
end

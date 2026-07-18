# frozen_string_literal: true

module ::MessagingPreferences
  class Acknowledgement < ::ActiveRecord::Base
    self.table_name = "messaging_preference_acknowledgements"

    belongs_to :viewer, class_name: "::User", foreign_key: :viewer_user_id
    belongs_to :target, class_name: "::User", foreign_key: :target_user_id

    validates :viewer_user_id, :target_user_id, :preferences_digest, :acknowledged_at, presence: true
    validates :preferences_digest, length: { is: 64 }
    validates :viewer_user_id, uniqueness: { scope: :target_user_id }
    validate :viewer_and_target_must_differ

    def self.table_ready?
      connection.data_source_exists?(table_name)
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      false
    end

    private

    def viewer_and_target_must_differ
      return if viewer_user_id.blank? || target_user_id.blank?
      return unless viewer_user_id == target_user_id

      errors.add(:target_user_id, "must differ from viewer_user_id")
    end
  end
end

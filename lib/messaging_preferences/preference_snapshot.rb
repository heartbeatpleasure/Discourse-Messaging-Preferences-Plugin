# frozen_string_literal: true

require "digest"

module ::MessagingPreferences
  class PreferenceSnapshot
    DIGEST_VERSION = 1

    attr_reader :target_user

    def self.digest_for(works_well:, please_avoid:)
      normalized_works_well = ::MessagingPreferences.normalize_text(works_well)
      normalized_please_avoid = ::MessagingPreferences.normalize_text(please_avoid)
      return if normalized_works_well.blank? && normalized_please_avoid.blank?

      payload = [DIGEST_VERSION, normalized_works_well, normalized_please_avoid]
      Digest::SHA256.hexdigest(payload.join("\u001F"))
    end

    def initialize(target_user)
      @target_user = target_user
    end

    def works_well
      value_for(::MessagingPreferences::WORKS_WELL_FIELD)
    end

    def please_avoid
      value_for(::MessagingPreferences::PLEASE_AVOID_FIELD)
    end

    def present?
      works_well.present? || please_avoid.present?
    end

    def updated_at
      field_rows.values.filter_map(&:updated_at).max
    end

    def digest
      return if !present?

      # The digest represents the content the viewer saw. Timestamps are not
      # included, so saving unchanged text does not unnecessarily invalidate
      # an existing acknowledgement.
      self.class.digest_for(works_well: works_well, please_avoid: please_avoid)
    end

    def acknowledgement_for(viewer)
      return if viewer.blank? || viewer.id == target_user.id || !present?
      return if !::MessagingPreferences::Acknowledgement.table_ready?

      ::MessagingPreferences::Acknowledgement.find_by(
        viewer_user_id: viewer.id,
        target_user_id: target_user.id,
        preferences_digest: digest,
      )
    end

    def payload_for(viewer)
      acknowledgement = acknowledgement_for(viewer)
      acknowledged = acknowledgement.present?
      staff_bypass =
        viewer&.staff? && SiteSetting.messaging_preferences_staff_bypass_acknowledgement
      own_preferences = viewer&.id == target_user.id
      acknowledgement_enabled = SiteSetting.messaging_preferences_require_acknowledgement

      {
        username: target_user.username,
        works_well: works_well,
        please_avoid: please_avoid,
        has_preferences: present?,
        preferences_digest: digest,
        updated_at: updated_at&.iso8601(6),
        acknowledged: acknowledged,
        acknowledged_at: acknowledgement&.acknowledged_at&.iso8601(6),
        acknowledgement_required:
          present? && acknowledgement_enabled && !own_preferences && !staff_bypass &&
            !acknowledged,
        can_bypass_acknowledgement: !!staff_bypass,
      }
    end

    private

    def field_rows
      @field_rows ||=
        ::UserCustomField
          .where(user_id: target_user.id, name: ::MessagingPreferences::FIELD_NAMES)
          .order(:id)
          .index_by(&:name)
    end

    def value_for(field_name)
      ::MessagingPreferences.normalize_text(field_rows[field_name]&.value)
    end
  end
end

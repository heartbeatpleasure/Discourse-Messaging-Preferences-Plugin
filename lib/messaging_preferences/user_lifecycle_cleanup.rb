# frozen_string_literal: true

module ::MessagingPreferences
  class UserLifecycleCleanup
    def self.purge_user!(user_or_id)
      user_id = user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
      user_id = user_id.to_i
      return { success: true, removed_fields: 0, removed_acknowledgements: 0 } if user_id <= 0

      removed_fields =
        ::UserCustomField.where(
          user_id: user_id,
          name: ::MessagingPreferences::FIELD_NAMES,
        ).delete_all

      removed_acknowledgements =
        if ::MessagingPreferences::Acknowledgement.table_ready?
          ::MessagingPreferences::Acknowledgement.where(
            "viewer_user_id = :user_id OR target_user_id = :user_id",
            user_id: user_id,
          ).delete_all
        else
          0
        end

      {
        success: true,
        removed_fields: removed_fields,
        removed_acknowledgements: removed_acknowledgements,
      }
    end
  end
end

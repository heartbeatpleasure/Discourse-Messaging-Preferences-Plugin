# frozen_string_literal: true

module ::MessagingPreferences
  class DataMaintenance
    BATCH_SIZE = 1_000

    class << self
      def status(user_id: nil)
        retention_days = activity_retention_days

        payload = {
          retention_days: retention_days,
          retention_unlimited: retention_days.zero?,
          acknowledgement_records: acknowledgement_scope.count,
          event_records: event_scope.count,
          expired_event_records: expired_event_scope.count,
          duplicate_custom_field_records: duplicate_custom_field_record_count,
          blank_custom_field_records: blank_custom_field_record_count,
          invalid_acknowledgement_records: invalid_acknowledgement_scope.count,
          orphaned_acknowledgement_records: orphaned_acknowledgement_scope.count,
          orphaned_event_records: orphaned_event_scope.count,
        }

        if user_id.present?
          user_id = user_id.to_i
          payload[:selected_user] = {
            preference_fields: preference_field_scope.where(user_id: user_id).count,
            acknowledgement_records:
              acknowledgement_scope.where(
                "viewer_user_id = :user_id OR target_user_id = :user_id",
                user_id: user_id,
              ).count,
            received_acknowledgement_records:
              acknowledgement_scope.where(target_user_id: user_id).count,
            event_records:
              event_scope.where(
                "actor_user_id = :user_id OR target_user_id = :user_id",
                user_id: user_id,
              ).count,
          }
        end

        payload
      end

      def cleanup!
        {
          expired_events: purge_expired_events!,
          orphaned_acknowledgements: delete_in_batches(orphaned_acknowledgement_scope),
          orphaned_events: delete_in_batches(orphaned_event_scope),
          invalid_acknowledgements: delete_in_batches(invalid_acknowledgement_scope),
          duplicate_custom_fields: cleanup_duplicate_custom_fields!,
          normalized_custom_fields: normalize_custom_fields!,
          blank_custom_fields: cleanup_blank_custom_fields!,
        }
      end

      def purge_expired_events!
        delete_in_batches(expired_event_scope)
      end

      def reset_acknowledgements_for_user!(user)
        return 0 if !::MessagingPreferences::Acknowledgement.table_ready?

        ::MessagingPreferences::Acknowledgement.where(
          "viewer_user_id = :user_id OR target_user_id = :user_id",
          user_id: user.id,
        ).delete_all
      end

      def reset_all_acknowledgements!
        return 0 if !::MessagingPreferences::Acknowledgement.table_ready?

        ::MessagingPreferences::Acknowledgement.delete_all
      end

      def clear_all_events!
        return 0 if !::MessagingPreferences::Event.table_ready?

        ::MessagingPreferences::Event.delete_all
      end

      def clear_preferences_for_user!(user:, actor:)
        removed_fields = 0
        removed_acknowledgements = 0
        recorded_event = false

        ::User.transaction do
          locked_user = ::User.lock.find(user.id)
          before_snapshot = ::MessagingPreferences::PreferenceSnapshot.new(locked_user)
          before_snapshot.digest

          removed_fields = preference_field_scope.where(user_id: locked_user.id).delete_all
          removed_acknowledgements =
            acknowledgement_scope.where(target_user_id: locked_user.id).delete_all

          locked_user.clear_custom_fields

          recorded_event =
            ::MessagingPreferences::EventRecorder.record_admin_preference_clear!(
              actor: actor,
              target: locked_user,
              before_snapshot: before_snapshot,
            )
        end

        {
          removed_fields: removed_fields,
          removed_acknowledgements: removed_acknowledgements,
          recorded_event: recorded_event,
        }
      end

      def activity_retention_days
        SiteSetting.messaging_preferences_activity_retention_days.to_i.clamp(0, 36_500)
      end

      private

      def acknowledgement_scope
        return ::MessagingPreferences::Acknowledgement.none if !::MessagingPreferences::Acknowledgement.table_ready?

        ::MessagingPreferences::Acknowledgement.all
      end

      def event_scope
        return ::MessagingPreferences::Event.none if !::MessagingPreferences::Event.table_ready?

        ::MessagingPreferences::Event.all
      end

      def preference_field_scope
        ::UserCustomField.where(name: ::MessagingPreferences::FIELD_NAMES)
      end

      def expired_event_scope
        return event_scope.none if activity_retention_days.zero?

        event_scope.where("occurred_at < ?", activity_retention_days.days.ago)
      end

      def orphaned_acknowledgement_scope
        scope = acknowledgement_scope
        return scope.none if !::MessagingPreferences::Acknowledgement.table_ready?

        valid_user_ids = ::User.select(:id)
        scope
          .where.not(viewer_user_id: valid_user_ids)
          .or(scope.where.not(target_user_id: valid_user_ids))
      end

      def orphaned_event_scope
        scope = event_scope
        return scope.none if !::MessagingPreferences::Event.table_ready?

        valid_user_ids = ::User.select(:id)
        scope
          .where.not(actor_user_id: valid_user_ids)
          .or(scope.where.not(target_user_id: valid_user_ids))
      end

      def invalid_acknowledgement_scope
        scope = acknowledgement_scope
        return scope.none if !::MessagingPreferences::Acknowledgement.table_ready?

        scope.where(
          "viewer_user_id = target_user_id OR preferences_digest IS NULL OR LENGTH(preferences_digest) <> 64",
        )
      end

      def duplicate_custom_field_groups
        preference_field_scope
          .group(:user_id, :name)
          .having("COUNT(*) > 1")
          .count
      end

      def duplicate_custom_field_record_count
        duplicate_custom_field_groups.values.sum { |count| count - 1 }
      end

      def blank_custom_field_record_count
        preference_field_scope.count do |field|
          ::MessagingPreferences.normalize_text(field.value).blank?
        end
      end

      def cleanup_blank_custom_fields!
        removed = 0

        preference_user_scope.find_each do |user|
          user.with_lock do
            preference_fields_for(user.id).find_each do |field|
              next if ::MessagingPreferences.normalize_text(field.value).present?

              field.delete
              removed += 1
            end
          end
        end

        removed
      end

      def cleanup_duplicate_custom_fields!
        removed = 0

        duplicate_custom_field_groups.each_key do |user_id, name|
          user = ::User.find_by(id: user_id)
          next if user.blank?

          user.with_lock do
            ids =
              ::UserCustomField
                .where(user_id: user.id, name: name)
                .order(id: :desc)
                .pluck(:id)

            duplicate_ids = ids.drop(1)
            next if duplicate_ids.empty?

            removed += ::UserCustomField.where(id: duplicate_ids).delete_all
          end
        end

        removed
      end

      def normalize_custom_fields!
        normalized = 0

        preference_user_scope.find_each do |user|
          user.with_lock do
            preference_fields_for(user.id).find_each do |field|
              value = ::MessagingPreferences.normalize_text(field.value)
              next if value.blank? || value == field.value

              field.update_column(:value, value)
              normalized += 1
            end
          end
        end

        normalized
      end

      def preference_user_scope
        ::User.where(id: preference_field_scope.select(:user_id)).order(:id)
      end

      def preference_fields_for(user_id)
        preference_field_scope.where(user_id: user_id).order(:id)
      end

      def delete_in_batches(scope)
        removed = 0
        scope.in_batches(of: BATCH_SIZE) { |batch| removed += batch.delete_all }
        removed
      end
    end
  end
end

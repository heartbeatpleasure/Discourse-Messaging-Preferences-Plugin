# frozen_string_literal: true

module ::MessagingPreferences
  class PreferencesController < ::ApplicationController
    requires_plugin ::MessagingPreferences::PLUGIN_NAME

    UPDATE_RATE_LIMIT = 30
    ACKNOWLEDGEMENT_RATE_LIMIT = 60
    TARGET_ACKNOWLEDGEMENT_RATE_LIMIT = 10

    skip_before_action :check_xhr, raise: false

    before_action :ensure_logged_in
    before_action :ensure_enabled
    before_action :disable_response_caching

    def show
      snapshot = ::MessagingPreferences::PreferenceSnapshot.new(target_user)
      render json: { messaging_preferences: snapshot.payload_for(current_user) }
    end

    def update
      RateLimiter.new(
        current_user,
        "messaging-preferences-update",
        UPDATE_RATE_LIMIT,
        1.minute,
      ).performed!

      values = {
        ::MessagingPreferences::WORKS_WELL_FIELD =>
          ::MessagingPreferences.normalize_text(params[:works_well]),
        ::MessagingPreferences::PLEASE_AVOID_FIELD =>
          ::MessagingPreferences.normalize_text(params[:please_avoid]),
      }

      if values.values.any? { |value| value.length > ::MessagingPreferences::MAX_LENGTH }
        return render json: {
                        errors: [
                          I18n.t(
                            "messaging_preferences.errors.too_long",
                            maximum: ::MessagingPreferences::MAX_LENGTH,
                          ),
                        ],
                        error_type: "too_long",
                      },
                      status: :unprocessable_entity
      end

      snapshot = nil

      ::User.transaction do
        locked_user = ::User.lock.find(current_user.id)
        before_snapshot = ::MessagingPreferences::PreferenceSnapshot.new(locked_user)
        before_snapshot.digest

        values.each do |field_name, value|
          persist_field!(locked_user.id, field_name, value)
        end

        locked_user.clear_custom_fields
        snapshot = ::MessagingPreferences::PreferenceSnapshot.new(locked_user)
        ::MessagingPreferences::EventRecorder.record_preference_change!(
          user: locked_user,
          before_snapshot: before_snapshot,
          after_snapshot: snapshot,
        )
      end

      render json: { success: true, messaging_preferences: snapshot.payload_for(current_user) }
    end

    def acknowledge
      RateLimiter.new(
        current_user,
        "messaging-preferences-acknowledge",
        ACKNOWLEDGEMENT_RATE_LIMIT,
        1.minute,
      ).performed!

      if !::MessagingPreferences::Acknowledgement.table_ready?
        return render_error("database_not_ready", :service_unavailable)
      end

      target = target_user

      RateLimiter.new(
        current_user,
        "messaging-preferences-acknowledge-#{target.id}",
        TARGET_ACKNOWLEDGEMENT_RATE_LIMIT,
        1.minute,
      ).performed!

      if target.id == current_user.id
        return render_error("own_preferences", :unprocessable_entity)
      end

      supplied_digest = params[:preferences_digest].to_s
      error_key = nil
      error_status = nil
      acknowledgement = nil
      snapshot = nil

      ::User.transaction do
        locked_users =
          ::User
            .where(id: [current_user.id, target.id], active: true, staged: false)
            .order(:id)
            .lock
            .index_by(&:id)

        locked_viewer = locked_users[current_user.id]
        locked_target = locked_users[target.id]
        raise ActiveRecord::RecordNotFound if locked_viewer.blank? || locked_target.blank?

        snapshot = ::MessagingPreferences::PreferenceSnapshot.new(locked_target)

        if !snapshot.present?
          error_key = "no_preferences"
          error_status = :unprocessable_entity
          raise ActiveRecord::Rollback
        end

        current_digest = snapshot.digest
        digest_matches =
          supplied_digest.bytesize == current_digest.bytesize &&
            ActiveSupport::SecurityUtils.secure_compare(supplied_digest, current_digest)

        if supplied_digest.blank? || !digest_matches
          error_key = "stale_preferences"
          error_status = :conflict
          raise ActiveRecord::Rollback
        end

        acknowledgement =
          ::MessagingPreferences::Acknowledgement.lock.find_or_initialize_by(
            viewer_user_id: locked_viewer.id,
            target_user_id: locked_target.id,
          )
        already_current = acknowledgement.persisted? && acknowledgement.preferences_digest == current_digest

        if !already_current
          acknowledgement.preferences_digest = current_digest
          acknowledgement.acknowledged_at = Time.zone.now
          acknowledgement.save!
        end

        ::MessagingPreferences::EventRecorder.record_acknowledgement!(
          viewer: locked_viewer,
          target: locked_target,
          digest: current_digest,
          already_current: already_current,
        )
      end

      return render_error(error_key, error_status) if error_key.present?

      render json: {
        success: true,
        messaging_preferences: snapshot.payload_for(current_user).merge(
          acknowledged: true,
          acknowledged_at: acknowledgement.acknowledged_at.iso8601(6),
          acknowledgement_required: false,
        ),
      }
    end

    private

    def ensure_enabled
      raise Discourse::NotFound if !SiteSetting.messaging_preferences_enabled
    end

    def disable_response_caching
      response.headers["Cache-Control"] = "no-store"
    end

    def target_user
      @target_user ||=
        ::User.where(active: true, staged: false).find_by!(
          username_lower: params[:username].to_s.downcase,
        )
    end

    def persist_field!(user_id, field_name, value)
      fields = ::UserCustomField.where(user_id: user_id, name: field_name).order(:id)

      if value.blank?
        fields.delete_all
        return
      end

      field = fields.first || ::UserCustomField.new(user_id: user_id, name: field_name)
      field.value = value
      field.save!

      fields.where.not(id: field.id).delete_all
    end

    def render_error(key, status)
      render json: {
               errors: [I18n.t("messaging_preferences.errors.#{key}")],
               error_type: key,
             },
             status: status
    end
  end
end

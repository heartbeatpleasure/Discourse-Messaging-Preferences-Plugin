# frozen_string_literal: true

module ::MessagingPreferences
  class PreferencesController < ::ApplicationController
    requires_plugin ::MessagingPreferences::PLUGIN_NAME

    skip_before_action :check_xhr, raise: false

    before_action :ensure_logged_in
    before_action :ensure_enabled
    before_action :disable_response_caching

    def show
      snapshot = ::MessagingPreferences::PreferenceSnapshot.new(target_user)
      render json: { messaging_preferences: snapshot.payload_for(current_user) }
    end

    def update
      RateLimiter.new(current_user, "messaging-preferences-update", 30, 1.minute).performed!

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

      before_snapshot = ::MessagingPreferences::PreferenceSnapshot.new(current_user)
      before_snapshot.digest

      ::UserCustomField.transaction do
        values.each { |field_name, value| persist_field!(field_name, value) }
      end

      current_user.clear_custom_fields
      snapshot = ::MessagingPreferences::PreferenceSnapshot.new(current_user)
      ::MessagingPreferences::EventRecorder.record_preference_change!(
        user: current_user,
        before_snapshot: before_snapshot,
        after_snapshot: snapshot,
      )

      render json: { success: true, messaging_preferences: snapshot.payload_for(current_user) }
    end

    def acknowledge
      RateLimiter.new(current_user, "messaging-preferences-acknowledge", 60, 1.minute).performed!

      if !::MessagingPreferences::Acknowledgement.table_ready?
        return render_error("database_not_ready", :service_unavailable)
      end

      target = target_user

      if target.id == current_user.id
        return render_error("own_preferences", :unprocessable_entity)
      end

      snapshot = ::MessagingPreferences::PreferenceSnapshot.new(target)
      return render_error("no_preferences", :unprocessable_entity) if !snapshot.present?

      supplied_digest = params[:preferences_digest].to_s
      current_digest = snapshot.digest
      digest_matches =
        supplied_digest.bytesize == current_digest.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(supplied_digest, current_digest)

      if supplied_digest.blank? || !digest_matches
        return render_error("stale_preferences", :conflict)
      end

      existing_acknowledgement =
        ::MessagingPreferences::Acknowledgement.find_by(
          viewer_user_id: current_user.id,
          target_user_id: target.id,
        )
      already_current = existing_acknowledgement&.preferences_digest == snapshot.digest

      acknowledgement = existing_acknowledgement

      if !already_current
        now = Time.zone.now
        attributes = {
          viewer_user_id: current_user.id,
          target_user_id: target.id,
          preferences_digest: snapshot.digest,
          acknowledged_at: now,
          created_at: now,
          updated_at: now,
        }

        ::MessagingPreferences::Acknowledgement.upsert(
          attributes,
          unique_by: %i[viewer_user_id target_user_id],
        )

        acknowledgement = ::MessagingPreferences::Acknowledgement.find_by!(
          viewer_user_id: current_user.id,
          target_user_id: target.id,
        )
      end

      ::MessagingPreferences::EventRecorder.record_acknowledgement!(
        viewer: current_user,
        target: target,
        digest: snapshot.digest,
        already_current: already_current,
      )

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

    def persist_field!(field_name, value)
      fields = ::UserCustomField.where(user_id: current_user.id, name: field_name).order(:id)

      if value.blank?
        fields.delete_all
        return
      end

      field = fields.first || ::UserCustomField.new(user_id: current_user.id, name: field_name)
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

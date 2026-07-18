# frozen_string_literal: true

module ::MessagingPreferences
  class AdminActivityController < ::Admin::AdminController
    requires_plugin ::MessagingPreferences::PLUGIN_NAME

    ADMIN_ACTION_RATE_LIMIT = 20

    before_action :disable_response_caching

    def index
      render_json_dump(
        ::MessagingPreferences::AdminActivity.payload(
          user_id: params[:user_id],
          period: params[:period],
          event_filter: params[:event_filter],
          page: params[:page],
          user_page: params[:user_page],
        ),
      )
    end

    def reset_user_acknowledgements
      rate_limit_admin_action!
      user = find_active_user!
      removed = ::MessagingPreferences::DataMaintenance.reset_acknowledgements_for_user!(user)
      recorded_event =
        ::MessagingPreferences::EventRecorder.record_admin_reset_member_acknowledgements!(
          actor: current_user,
          target: user,
          removed_count: removed,
        )

      render_json_dump(
        success: true,
        removed_acknowledgements: removed,
        recorded_event: recorded_event,
      )
    end

    def clear_user_preferences
      rate_limit_admin_action!
      user = find_active_user!
      result =
        ::MessagingPreferences::DataMaintenance.clear_preferences_for_user!(
          user: user,
          actor: current_user,
        )

      render_json_dump({ success: true }.merge(result))
    end

    def reset_all_acknowledgements
      rate_limit_admin_action!
      removed = ::MessagingPreferences::DataMaintenance.reset_all_acknowledgements!
      recorded_event =
        ::MessagingPreferences::EventRecorder.record_admin_reset_all_acknowledgements!(
          actor: current_user,
          removed_count: removed,
        )

      render_json_dump(
        success: true,
        removed_acknowledgements: removed,
        recorded_event: recorded_event,
      )
    end

    def clear_activity_history
      rate_limit_admin_action!
      removed = ::MessagingPreferences::DataMaintenance.clear_all_events!

      render_json_dump(success: true, removed_events: removed)
    end

    def run_maintenance
      rate_limit_admin_action!
      result = ::MessagingPreferences::DataMaintenance.cleanup!
      recorded_event =
        ::MessagingPreferences::EventRecorder.record_admin_sitewide_cleanup!(
          actor: current_user,
        )

      render_json_dump(success: true, removed: result, recorded_event: recorded_event)
    end

    private

    def disable_response_caching
      response.headers["Cache-Control"] = "no-store"
    end

    def rate_limit_admin_action!
      RateLimiter.new(
        current_user,
        "messaging-preferences-admin-maintenance",
        ADMIN_ACTION_RATE_LIMIT,
        1.minute,
      ).performed!
    end

    def find_active_user!
      ::User.where(active: true, staged: false).find(params[:user_id].to_i)
    end
  end
end

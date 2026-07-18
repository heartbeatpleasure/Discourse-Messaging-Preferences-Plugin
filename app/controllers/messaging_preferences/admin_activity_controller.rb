# frozen_string_literal: true

module ::MessagingPreferences
  class AdminActivityController < ::Admin::AdminController
    requires_plugin ::MessagingPreferences::PLUGIN_NAME

    def index
      response.headers["Cache-Control"] = "no-store"
      render_json_dump(
        ::MessagingPreferences::AdminActivity.payload(user_id: params[:user_id]),
      )
    end
  end
end

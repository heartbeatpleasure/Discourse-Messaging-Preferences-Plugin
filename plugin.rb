# frozen_string_literal: true

# name: Discourse-Messaging-Preferences-Plugin
# about: Lets members define private messaging preferences for personal messages and direct chats.
# version: 0.6.0
# authors: Chris
# url: https://github.com/xxxxxx/Discourse-Messaging-Preferences-Plugin

add_admin_route "admin.messaging_preferences.title", "messagingPreferences"

enabled_site_setting :messaging_preferences_enabled

module ::MessagingPreferences
  PLUGIN_NAME = "Discourse-Messaging-Preferences-Plugin"
  WORKS_WELL_FIELD = "messaging_preferences_works_well"
  PLEASE_AVOID_FIELD = "messaging_preferences_please_avoid"
  FIELD_NAMES = [WORKS_WELL_FIELD, PLEASE_AVOID_FIELD].freeze
  MAX_LENGTH = 500
  MAX_STORAGE_BYTES = MAX_LENGTH * 4

  def self.normalize_text(value)
    value
      .to_s
      .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      .delete("\u0000")
      .gsub(/\r\n?/, "\n")
      .strip
  end
end

after_initialize do
  require_dependency File.expand_path(
    "app/models/messaging_preferences/acknowledgement.rb",
    __dir__,
  )
  require_dependency File.expand_path(
    "app/models/messaging_preferences/event.rb",
    __dir__,
  )
  require_relative "lib/messaging_preferences/preference_snapshot"
  require_relative "lib/messaging_preferences/event_recorder"
  require_relative "lib/messaging_preferences/admin_activity"
  require_relative "lib/messaging_preferences/data_maintenance"
  require_relative "lib/messaging_preferences/user_archive_export"
  require_relative "lib/messaging_preferences/user_archive_extension"
  require_relative "lib/messaging_preferences/user_lifecycle_cleanup"
  require_dependency File.expand_path(
    "app/controllers/messaging_preferences/preferences_controller.rb",
    __dir__,
  )
  require_dependency File.expand_path(
    "app/controllers/messaging_preferences/admin_activity_controller.rb",
    __dir__,
  )

  ::MessagingPreferences::UserArchiveExtension.install!

  ::MessagingPreferences::FIELD_NAMES.each do |field_name|
    register_editable_user_custom_field field_name
    register_user_custom_field_type(
      field_name,
      :string,
      max_length: ::MessagingPreferences::MAX_STORAGE_BYTES,
    )
    DiscoursePluginRegistry.serialized_current_user_fields << field_name
  end

  add_model_callback(::UserCustomField, :before_validation) do
    if ::MessagingPreferences::FIELD_NAMES.include?(name)
      self.value = ::MessagingPreferences.normalize_text(value)
      if value.length > ::MessagingPreferences::MAX_LENGTH
        errors.add(
          :base,
          I18n.t(
            "messaging_preferences.errors.too_long",
            maximum: ::MessagingPreferences::MAX_LENGTH,
          ),
        )
      end
    end
  end

  # User custom fields saved through User#save bypass UserCustomField callbacks.
  # Normalize the two editable values on the user model before core validates
  # and persists them.
  add_model_callback(::User, :before_validation) do
    unless custom_fields_clean?
      ::MessagingPreferences::FIELD_NAMES.each do |field_name|
        next unless custom_fields.key?(field_name)

        normalized_value =
          ::MessagingPreferences.normalize_text(custom_fields[field_name])

        if normalized_value.length > ::MessagingPreferences::MAX_LENGTH
          errors.add(
            :base,
            I18n.t(
              "messaging_preferences.errors.too_long",
              maximum: ::MessagingPreferences::MAX_LENGTH,
            ),
          )
        else
          custom_fields[field_name] = normalized_value
        end
      end
    end
  end

  # Remove private preferences and relationship data before the user row goes
  # away. Database foreign keys provide an additional safety net.
  add_model_callback(::User, :before_destroy) do
    ::MessagingPreferences::UserLifecycleCleanup.purge_user!(id)
  end

  on(:user_destroyed) do |user|
    ::MessagingPreferences::UserLifecycleCleanup.purge_user!(user)
  end

  on(:user_anonymized) do |args|
    user = args.is_a?(Hash) ? args[:user] : args
    ::MessagingPreferences::UserLifecycleCleanup.purge_user!(user) if user.present?
  end

  Discourse::Application.routes.append do
    get "/admin/plugins/messaging-preferences" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/messaging-preferences-activity" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/messaging-preferences/activity" =>
          "messaging_preferences/admin_activity#index",
        defaults: { format: :json },
        constraints: AdminConstraint.new
    delete "/admin/plugins/messaging-preferences/activity/users/:user_id/acknowledgements" =>
             "messaging_preferences/admin_activity#reset_user_acknowledgements",
           defaults: { format: :json },
           constraints: AdminConstraint.new
    delete "/admin/plugins/messaging-preferences/activity/users/:user_id/preferences" =>
             "messaging_preferences/admin_activity#clear_user_preferences",
           defaults: { format: :json },
           constraints: AdminConstraint.new
    delete "/admin/plugins/messaging-preferences/activity/acknowledgements" =>
             "messaging_preferences/admin_activity#reset_all_acknowledgements",
           defaults: { format: :json },
           constraints: AdminConstraint.new
    delete "/admin/plugins/messaging-preferences/activity/history" =>
             "messaging_preferences/admin_activity#clear_activity_history",
           defaults: { format: :json },
           constraints: AdminConstraint.new
    post "/admin/plugins/messaging-preferences/activity/maintenance" =>
           "messaging_preferences/admin_activity#run_maintenance",
         defaults: { format: :json },
         constraints: AdminConstraint.new

    get "/messaging-preferences/v1/users/:username" =>
          "messaging_preferences/preferences#show",
        defaults: { format: :json }

    put "/messaging-preferences/v1/me" =>
          "messaging_preferences/preferences#update",
        defaults: { format: :json }

    post "/messaging-preferences/v1/users/:username/acknowledge" =>
           "messaging_preferences/preferences#acknowledge",
         defaults: { format: :json }
  end
end

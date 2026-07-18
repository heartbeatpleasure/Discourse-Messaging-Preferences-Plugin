# frozen_string_literal: true

module Jobs
  module MessagingPreferences
    class CleanupActivity < ::Jobs::Scheduled
      every 1.day

      def execute(_args)
        return if !SiteSetting.messaging_preferences_enabled

        ::MessagingPreferences::DataMaintenance.cleanup!
      end
    end
  end
end

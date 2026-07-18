# frozen_string_literal: true

module ::MessagingPreferences
  module UserArchiveExtension
    COMPONENT_NAME = "messaging_preferences"

    class << self
      def install!
        require_dependency "jobs/regular/export_user_archive"

        components = ::Jobs::ExportUserArchive::COMPONENTS
        components << COMPONENT_NAME if !components.include?(COMPONENT_NAME)

        if !::Jobs::ExportUserArchive.ancestors.include?(self)
          ::Jobs::ExportUserArchive.prepend(self)
        end
      end
    end

    def include_messaging_preferences?
      ::MessagingPreferences::UserArchiveExport.data_present?(@archive_for_user)
    end

    def messaging_preferences_filetype
      :json
    end

    def messaging_preferences_export
      ::MessagingPreferences::UserArchiveExport.payload(@archive_for_user)
    end
  end
end

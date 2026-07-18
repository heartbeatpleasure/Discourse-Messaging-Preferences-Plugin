# frozen_string_literal: true

RSpec.describe MessagingPreferences::UserArchiveExtension do
  fab!(:user) { Fabricate(:user) }

  before do
    UserCustomField.create!(
      user_id: user.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "A clear introduction.",
    )
  end

  it "adds a private JSON component to the standard user archive" do
    expect(Jobs::ExportUserArchive::COMPONENTS).to include("messaging_preferences")

    exporter = Jobs::ExportUserArchive.new
    exporter.archive_for_user = user

    expect(exporter.include_messaging_preferences?).to eq(true)
    expect(exporter.messaging_preferences_filetype).to eq(:json)
    expect(exporter.messaging_preferences_export.dig(:preferences, :works_well)).to eq(
      "A clear introduction.",
    )
  end
end

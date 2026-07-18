# frozen_string_literal: true

RSpec.describe User do
  fab!(:user) { Fabricate(:user) }

  it "normalizes messaging preferences saved through the user model" do
    user.custom_fields[MessagingPreferences::WORKS_WELL_FIELD] =
      "  Introduce yourself.\r\nExplain why you are messaging.  "

    user.save!

    expect(
      UserCustomField.find_by!(
        user_id: user.id,
        name: MessagingPreferences::WORKS_WELL_FIELD,
      ).value,
    ).to eq("Introduce yourself.\nExplain why you are messaging.")
  end

  it "rejects preferences longer than 500 Unicode characters" do
    user.custom_fields[MessagingPreferences::PLEASE_AVOID_FIELD] = "🙂" * 501

    expect(user).not_to be_valid
    expect(user.errors[:base]).to include(
      I18n.t(
        "messaging_preferences.errors.too_long",
        maximum: MessagingPreferences::MAX_LENGTH,
      ),
    )
  end
end

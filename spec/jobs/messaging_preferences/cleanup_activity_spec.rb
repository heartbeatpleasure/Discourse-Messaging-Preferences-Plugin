# frozen_string_literal: true

RSpec.describe Jobs::MessagingPreferences::CleanupActivity do
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.messaging_preferences_enabled = true
    SiteSetting.messaging_preferences_activity_retention_days = 1
  end

  it "runs the configured activity cleanup" do
    old = MessagingPreferences::Event.create!(
      event_type: "preferences_updated",
      actor: user,
      target: user,
      preferences_digest: "a" * 64,
      occurred_at: 2.days.ago,
    )

    described_class.new.execute({})

    expect(MessagingPreferences::Event.exists?(old.id)).to eq(false)
  end

  it "does not remove activity when the plugin is disabled" do
    SiteSetting.messaging_preferences_enabled = false
    old = MessagingPreferences::Event.create!(
      event_type: "preferences_updated",
      actor: user,
      target: user,
      preferences_digest: "a" * 64,
      occurred_at: 2.days.ago,
    )

    described_class.new.execute({})

    expect(MessagingPreferences::Event.exists?(old.id)).to eq(true)
  end
end

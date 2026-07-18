# frozen_string_literal: true

RSpec.describe MessagingPreferences::Event do
  fab!(:actor) { Fabricate(:user) }
  fab!(:target) { Fabricate(:user) }

  it "stores a privacy-safe preference activity event" do
    event = described_class.create!(
      event_type: "preferences_updated",
      actor: actor,
      target: actor,
      preferences_digest: "a" * 64,
      occurred_at: Time.zone.now,
    )

    expect(event).to be_persisted
    expect(event.attributes).not_to have_key("preference_text")
  end

  it "accepts the supported admin activity event types" do
    MessagingPreferences::Event::ADMIN_EVENT_TYPES.each do |event_type|
      event = described_class.new(
        event_type: event_type,
        actor: actor,
        target: target,
        occurred_at: Time.zone.now,
      )

      expect(event).to be_valid
    end
  end

  it "rejects unknown event types" do
    event = described_class.new(
      event_type: "unknown",
      actor: actor,
      target: target,
      occurred_at: Time.zone.now,
    )

    expect(event).not_to be_valid
    expect(event.errors[:event_type]).to be_present
  end
end

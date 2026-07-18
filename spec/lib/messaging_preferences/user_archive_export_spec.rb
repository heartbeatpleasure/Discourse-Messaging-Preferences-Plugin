# frozen_string_literal: true

RSpec.describe MessagingPreferences::UserArchiveExport do
  fab!(:user) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:other) { Fabricate(:user) }

  before do
    UserCustomField.create!(
      user_id: user.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "My own preference text",
    )
    UserCustomField.create!(
      user_id: other.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Other member secret preference",
    )

    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: user,
      preferences_digest: MessagingPreferences::PreferenceSnapshot.new(user).digest,
      acknowledged_at: Time.zone.now,
    )
    MessagingPreferences::Acknowledgement.create!(
      viewer: user,
      target: other,
      preferences_digest: MessagingPreferences::PreferenceSnapshot.new(other).digest,
      acknowledged_at: Time.zone.now,
    )
    MessagingPreferences::Event.create!(
      event_type: "acknowledged",
      actor: user,
      target: other,
      preferences_digest: MessagingPreferences::PreferenceSnapshot.new(other).digest,
      occurred_at: Time.zone.now,
    )
  end

  it "exports the member's own preferences and acknowledgement relationships" do
    payload = described_class.payload(user)

    expect(payload.dig(:preferences, :works_well)).to eq("My own preference text")
    expect(payload[:acknowledgements_received].first[:member_username]).to eq(viewer.username)
    expect(payload[:acknowledgements_made].first[:member_username]).to eq(other.username)
    expect(payload[:activity_events].first).to include(
      event_type: "acknowledged",
      role: "actor",
      counterpart_username: other.username,
    )
  end

  it "never exports another member's preference text" do
    expect(described_class.payload(user).to_json).not_to include(
      "Other member secret preference",
    )
  end
end

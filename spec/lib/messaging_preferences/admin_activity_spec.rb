# frozen_string_literal: true

RSpec.describe MessagingPreferences::AdminActivity do
  fab!(:owner) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }

  before do
    UserCustomField.create!(
      user_id: owner.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
    digest = MessagingPreferences::PreferenceSnapshot.new(owner).digest
    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: owner,
      preferences_digest: digest,
      acknowledged_at: Time.zone.now,
    )
    MessagingPreferences::Event.create!(
      event_type: "acknowledged",
      actor: viewer,
      target: owner,
      preferences_digest: digest,
      occurred_at: Time.zone.now,
    )
  end

  it "returns aggregate current-state and tracked activity counts" do
    payload = described_class.payload

    expect(payload.dig(:summary, :members_with_preferences)).to eq(1)
    expect(payload.dig(:summary, :current_acknowledgements)).to eq(1)
    expect(payload.dig(:summary, :tracked_acknowledgements)).to eq(1)
  end

  it "returns member-specific relationships without preference text" do
    selected = described_class.payload(user_id: owner.id).fetch(:selected_user)

    expect(selected.dig(:user, :username)).to eq(owner.username)
    expect(selected.dig(:current_preferences, :has_preferences)).to eq(true)
    expect(selected.fetch(:acknowledgements_received).first.dig(:user, :username)).to eq(
      viewer.username,
    )
    expect(selected.to_json).not_to include("Introduce yourself")
  end

  it "searches active members by username" do
    results = described_class.search_users(owner.username[0, 3])

    expect(results.map { |user| user[:id] }).to include(owner.id)
  end
end

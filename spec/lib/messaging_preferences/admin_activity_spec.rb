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
    expect(payload.dig(:trend, :metrics, :acknowledgements, :current)).to eq(1)
  end

  it "returns member-specific relationships without preference text" do
    selected = described_class.payload(user_id: owner.id).fetch(:selected_user)

    expect(selected.dig(:user, :username)).to eq(owner.username)
    expect(selected.dig(:current_preferences, :has_preferences)).to eq(true)
    expect(selected.fetch(:acknowledgements_received).first.dig(:user, :username)).to eq(
      viewer.username,
    )
    expect(selected.dig(:events, :items).length).to eq(1)
    expect(selected.to_json).not_to include("Introduce yourself")
  end

  it "filters activity by period and event category" do
    MessagingPreferences::Event.create!(
      event_type: "preferences_updated",
      actor: owner,
      target: owner,
      occurred_at: 10.days.ago,
    )

    payload = described_class.payload(period: "7", event_filter: "preference_changes")

    expect(payload.dig(:filters, :period)).to eq("7")
    expect(payload.dig(:filters, :event_filter)).to eq("preference_changes")
    expect(payload.dig(:recent_events, :pagination, :total)).to eq(0)
    expect(payload.dig(:trend, :metrics, :preference_changes, :previous)).to eq(1)
    expect(payload.dig(:trend, :metrics, :acknowledgements, :current)).to eq(1)
  end

  it "paginates global and member activity independently" do
    30.times do |index|
      MessagingPreferences::Event.create!(
        event_type: "preferences_updated",
        actor: owner,
        target: owner,
        occurred_at: (index + 1).minutes.ago,
      )
    end

    payload =
      described_class.payload(
        user_id: owner.id,
        period: "all",
        event_filter: "preference_changes",
        page: 2,
        user_page: 2,
      )

    expect(payload.dig(:recent_events, :pagination, :total)).to eq(30)
    expect(payload.dig(:recent_events, :pagination, :page)).to eq(2)
    expect(payload.dig(:recent_events, :items).length).to eq(5)
    expect(payload.dig(:selected_user, :events, :pagination, :page)).to eq(2)
    expect(payload.dig(:selected_user, :events, :items).length).to eq(5)
  end

  it "falls back to safe filter defaults" do
    payload = described_class.payload(period: "invalid", event_filter: "invalid", page: -4)

    expect(payload.dig(:filters, :period)).to eq("30")
    expect(payload.dig(:filters, :event_filter)).to eq("all")
    expect(payload.dig(:recent_events, :pagination, :page)).to eq(1)
  end
end

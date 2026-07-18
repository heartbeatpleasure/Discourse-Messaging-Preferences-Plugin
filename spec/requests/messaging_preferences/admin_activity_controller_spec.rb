# frozen_string_literal: true

RSpec.describe MessagingPreferences::AdminActivityController, type: :request do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:member) { Fabricate(:user) }

  before do
    SiteSetting.messaging_preferences_enabled = true
    UserCustomField.create!(
      user_id: member.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
  end

  it "requires an administrator" do
    sign_in(member)

    get "/admin/plugins/messaging-preferences/activity.json"

    expect(response.status).not_to eq(200)
  end

  it "returns privacy-safe activity data to an administrator" do
    sign_in(admin)

    get "/admin/plugins/messaging-preferences/activity.json",
        params: { user_id: member.id }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("summary", "members_with_preferences")).to eq(1)
    expect(response.parsed_body.dig("selected_user", "user", "username")).to eq(
      member.username,
    )
    expect(response.body).not_to include("Introduce yourself")
  end

  it "applies period, event-type, and pagination parameters" do
    sign_in(admin)
    MessagingPreferences::Event.create!(
      event_type: "preferences_updated",
      actor: member,
      target: member,
      occurred_at: 10.days.ago,
    )

    get "/admin/plugins/messaging-preferences/activity.json",
        params: { period: "7", event_filter: "preference_changes", page: 2 }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("filters", "period")).to eq("7")
    expect(response.parsed_body.dig("filters", "event_filter")).to eq(
      "preference_changes",
    )
    expect(response.parsed_body.dig("recent_events", "pagination", "total")).to eq(0)
  end
end

RSpec.describe "Messaging Preferences admin maintenance", type: :request do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:member) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }

  before do
    SiteSetting.messaging_preferences_enabled = true
    SiteSetting.messaging_preferences_activity_retention_days = 365
    UserCustomField.create!(
      user_id: member.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: member,
      preferences_digest: MessagingPreferences::PreferenceSnapshot.new(member).digest,
      acknowledged_at: Time.zone.now,
    )
    MessagingPreferences::Event.create!(
      event_type: "acknowledged",
      actor: viewer,
      target: member,
      preferences_digest: MessagingPreferences::PreferenceSnapshot.new(member).digest,
      occurred_at: Time.zone.now,
    )
  end

  it "includes retention and maintenance counts in the activity payload" do
    sign_in(admin)

    get "/admin/plugins/messaging-preferences/activity.json",
        params: { user_id: member.id }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("maintenance", "retention_days")).to eq(365)
    expect(response.parsed_body.dig("maintenance", "event_records")).to eq(1)
    expect(
      response.parsed_body.dig(
        "maintenance",
        "selected_user",
        "acknowledgement_records",
      ),
    ).to eq(1)
  end

  it "lets an admin reset acknowledgement relationships for one member" do
    sign_in(admin)

    delete "/admin/plugins/messaging-preferences/activity/users/#{member.id}/acknowledgements.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["removed_acknowledgements"]).to eq(1)
    expect(MessagingPreferences::Acknowledgement.count).to eq(0)
  end

  it "lets an admin clear one member's preferences without exposing their text" do
    sign_in(admin)

    delete "/admin/plugins/messaging-preferences/activity/users/#{member.id}/preferences.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["removed_fields"]).to eq(1)
    expect(response.body).not_to include("Introduce yourself")
    expect(
      UserCustomField.where(user_id: member.id, name: MessagingPreferences::FIELD_NAMES),
    ).to be_empty
  end

  it "lets an admin clear recorded activity without removing current relationships" do
    sign_in(admin)

    delete "/admin/plugins/messaging-preferences/activity/history.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["removed_events"]).to eq(1)
    expect(MessagingPreferences::Event.count).to eq(0)
    expect(MessagingPreferences::Acknowledgement.count).to eq(1)
  end

  it "rejects maintenance actions from non-admin members" do
    sign_in(member)

    delete "/admin/plugins/messaging-preferences/activity/acknowledgements.json"

    expect(response.status).not_to eq(200)
    expect(MessagingPreferences::Acknowledgement.count).to eq(1)
  end
end

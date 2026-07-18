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

  it "returns member search results to an administrator" do
    sign_in(admin)

    get "/admin/plugins/messaging-preferences/user-search.json",
        params: { term: member.username[0, 3] }

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("users").map { |user| user["id"] }).to include(member.id)
  end
end

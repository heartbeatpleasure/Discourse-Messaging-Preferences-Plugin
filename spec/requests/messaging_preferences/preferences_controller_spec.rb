# frozen_string_literal: true

RSpec.describe "Messaging Preferences API", type: :request do
  fab!(:target) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.messaging_preferences_enabled = true
    SiteSetting.messaging_preferences_require_acknowledgement = true
    SiteSetting.messaging_preferences_staff_bypass_acknowledgement = true
    UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself and explain why you are messaging.",
    )
    UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::PLEASE_AVOID_FIELD,
      value: "Repeated messages.",
    )
    sign_in(viewer)
  end

  it "returns the target member's preferences without publishing them on the normal profile API" do
    get "/messaging-preferences/v1/users/#{target.username}"

    expect(response.status).to eq(200)
    preferences = response.parsed_body.fetch("messaging_preferences")
    expect(preferences["works_well"]).to eq(
      "Introduce yourself and explain why you are messaging.",
    )
    expect(preferences["please_avoid"]).to eq("Repeated messages.")
    expect(preferences["acknowledgement_required"]).to eq(true)

    get "/u/#{target.username}.json"

    normal_custom_fields = response.parsed_body.dig("user", "custom_fields") || {}
    expect(normal_custom_fields).not_to have_key(MessagingPreferences::WORKS_WELL_FIELD)
    expect(normal_custom_fields).not_to have_key(MessagingPreferences::PLEASE_AVOID_FIELD)

    sign_in(target)
    get "/u/#{target.username}.json"

    own_custom_fields = response.parsed_body.dig("user", "custom_fields") || {}
    expect(own_custom_fields[MessagingPreferences::WORKS_WELL_FIELD]).to eq(
      "Introduce yourself and explain why you are messaging.",
    )
    expect(own_custom_fields[MessagingPreferences::PLEASE_AVOID_FIELD]).to eq(
      "Repeated messages.",
    )
  end

  it "persists the current member's preferences through the plugin endpoint" do
    sign_in(target)

    put "/messaging-preferences/v1/me",
        params: {
          works_well: "  A clear introduction.  ",
          please_avoid: "Repeated messages.\r\nPressure to reply.",
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("messaging_preferences", "works_well")).to eq(
      "A clear introduction.",
    )
    expect(response.parsed_body.dig("messaging_preferences", "please_avoid")).to eq(
      "Repeated messages.\nPressure to reply.",
    )
    expect(
      UserCustomField.find_by!(
        user_id: target.id,
        name: MessagingPreferences::WORKS_WELL_FIELD,
      ).value,
    ).to eq("A clear introduction.")
  end

  it "removes empty preferences through the plugin endpoint" do
    sign_in(target)

    put "/messaging-preferences/v1/me", params: { works_well: "", please_avoid: "" }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("messaging_preferences", "has_preferences")).to eq(false)
    expect(
      UserCustomField.where(
        user_id: target.id,
        name: MessagingPreferences::FIELD_NAMES,
      ),
    ).to be_empty
  end

  it "rejects preference text longer than the configured maximum" do
    sign_in(target)

    put "/messaging-preferences/v1/me",
        params: { works_well: "x" * (MessagingPreferences::MAX_LENGTH + 1) }

    expect(response.status).to eq(422)
    expect(response.parsed_body["error_type"]).to eq("too_long")
  end

  it "stores an acknowledgement for the exact snapshot shown to the viewer" do
    get "/messaging-preferences/v1/users/#{target.username}"
    digest = response.parsed_body.dig("messaging_preferences", "preferences_digest")

    post "/messaging-preferences/v1/users/#{target.username}/acknowledge",
         params: { preferences_digest: digest }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("messaging_preferences", "acknowledged")).to eq(true)
    expect(
      response.parsed_body.dig("messaging_preferences", "acknowledgement_required"),
    ).to eq(false)
    expect(
      MessagingPreferences::Acknowledgement.exists?(
        viewer_user_id: viewer.id,
        target_user_id: target.id,
        preferences_digest: digest,
      ),
    ).to eq(true)
  end

  it "rejects an acknowledgement when the preferences changed after they were read" do
    get "/messaging-preferences/v1/users/#{target.username}"
    old_digest = response.parsed_body.dig("messaging_preferences", "preferences_digest")

    UserCustomField.find_by!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
    ).update!(value: "Updated preference.")

    post "/messaging-preferences/v1/users/#{target.username}/acknowledge",
         params: { preferences_digest: old_digest }

    expect(response.status).to eq(409)
    expect(response.parsed_body["error_type"]).to eq("stale_preferences")
    expect(MessagingPreferences::Acknowledgement.count).to eq(0)
  end

  it "lets staff view preferences without requiring acknowledgement" do
    sign_in(admin)

    get "/messaging-preferences/v1/users/#{target.username}"

    expect(response.status).to eq(200)
    expect(
      response.parsed_body.dig("messaging_preferences", "can_bypass_acknowledgement"),
    ).to eq(true)
    expect(
      response.parsed_body.dig("messaging_preferences", "acknowledgement_required"),
    ).to eq(false)
  end

  it "can expose preferences without requiring acknowledgement" do
    SiteSetting.messaging_preferences_require_acknowledgement = false

    get "/messaging-preferences/v1/users/#{target.username}"

    expect(response.status).to eq(200)
    preferences = response.parsed_body.fetch("messaging_preferences")
    expect(preferences["has_preferences"]).to eq(true)
    expect(preferences["acknowledgement_required"]).to eq(false)
    expect(preferences["acknowledged"]).to eq(false)
  end

  it "can require staff to acknowledge when the bypass setting is disabled" do
    SiteSetting.messaging_preferences_staff_bypass_acknowledgement = false
    sign_in(admin)

    get "/messaging-preferences/v1/users/#{target.username}"

    expect(response.status).to eq(200)
    preferences = response.parsed_body.fetch("messaging_preferences")
    expect(preferences["can_bypass_acknowledgement"]).to eq(false)
    expect(preferences["acknowledgement_required"]).to eq(true)
  end

  it "returns not found while the plugin setting is disabled" do
    SiteSetting.messaging_preferences_enabled = false

    get "/messaging-preferences/v1/users/#{target.username}"

    expect(response.status).to eq(404)
  end
end

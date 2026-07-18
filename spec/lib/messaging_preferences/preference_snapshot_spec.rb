# frozen_string_literal: true

RSpec.describe MessagingPreferences::PreferenceSnapshot do
  fab!(:target) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  def set_field(name, value)
    UserCustomField.create!(user_id: target.id, name: name, value: value)
  end

  it "returns a private plain-text snapshot and requires acknowledgement" do
    set_field(MessagingPreferences::WORKS_WELL_FIELD, "  Introduce yourself.\r\n  ")
    set_field(MessagingPreferences::PLEASE_AVOID_FIELD, "Repeated messages.")

    payload = described_class.new(target).payload_for(viewer)

    expect(payload[:works_well]).to eq("Introduce yourself.")
    expect(payload[:please_avoid]).to eq("Repeated messages.")
    expect(payload[:has_preferences]).to eq(true)
    expect(payload[:preferences_digest]).to match(/\A[0-9a-f]{64}\z/)
    expect(payload[:acknowledgement_required]).to eq(true)
  end

  it "does not require staff to acknowledge" do
    set_field(MessagingPreferences::WORKS_WELL_FIELD, "Be direct.")

    payload = described_class.new(target).payload_for(admin)

    expect(payload[:can_bypass_acknowledgement]).to eq(true)
    expect(payload[:acknowledgement_required]).to eq(false)
  end

  it "invalidates an acknowledgement after a preference changes" do
    field = UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
    snapshot = described_class.new(target)

    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: target,
      preferences_digest: snapshot.digest,
      acknowledged_at: Time.zone.now,
    )

    expect(described_class.new(target).payload_for(viewer)[:acknowledged]).to eq(true)

    field.update!(value: "Explain why you are messaging.")

    payload = described_class.new(target).payload_for(viewer)
    expect(payload[:acknowledged]).to eq(false)
    expect(payload[:acknowledgement_required]).to eq(true)
  end
end

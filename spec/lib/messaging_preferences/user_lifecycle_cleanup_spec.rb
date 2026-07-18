# frozen_string_literal: true

RSpec.describe MessagingPreferences::UserLifecycleCleanup do
  fab!(:target) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }

  before do
    UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: target,
      preferences_digest: "a" * 64,
      acknowledged_at: Time.zone.now,
    )
    MessagingPreferences::Event.create!(
      event_type: "acknowledged",
      actor: viewer,
      target: target,
      preferences_digest: "a" * 64,
      occurred_at: Time.zone.now,
    )
  end

  it "removes private fields and acknowledgement relationships" do
    result = described_class.purge_user!(target)

    expect(result).to include(
      success: true,
      removed_fields: 1,
      removed_acknowledgements: 1,
      removed_events: 1,
    )
    expect(
      UserCustomField.where(user_id: target.id, name: MessagingPreferences::FIELD_NAMES),
    ).to be_empty
    expect(MessagingPreferences::Acknowledgement.where(target_user_id: target.id)).to be_empty
    expect(MessagingPreferences::Event.where(target_user_id: target.id)).to be_empty
  end

  it "is idempotent" do
    described_class.purge_user!(target)
    result = described_class.purge_user!(target)

    expect(result).to include(success: true, removed_fields: 0, removed_acknowledgements: 0)
  end
end

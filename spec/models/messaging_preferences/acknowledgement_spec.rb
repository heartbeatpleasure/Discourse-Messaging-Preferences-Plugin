# frozen_string_literal: true

RSpec.describe MessagingPreferences::Acknowledgement do
  fab!(:viewer) { Fabricate(:user) }
  fab!(:target) { Fabricate(:user) }

  it "accepts one acknowledgement per viewer and target" do
    acknowledgement = described_class.create!(
      viewer: viewer,
      target: target,
      preferences_digest: "a" * 64,
      acknowledged_at: Time.zone.now,
    )

    expect(acknowledgement).to be_persisted
  end

  it "rejects an acknowledgement of the viewer's own preferences" do
    acknowledgement = described_class.new(
      viewer: viewer,
      target: viewer,
      preferences_digest: "a" * 64,
      acknowledged_at: Time.zone.now,
    )

    expect(acknowledgement).not_to be_valid
    expect(acknowledgement.errors[:target_user_id]).to be_present
  end

  it "enforces a unique viewer and target pair" do
    described_class.create!(
      viewer: viewer,
      target: target,
      preferences_digest: "a" * 64,
      acknowledged_at: Time.zone.now,
    )

    duplicate = described_class.new(
      viewer: viewer,
      target: target,
      preferences_digest: "b" * 64,
      acknowledged_at: Time.zone.now,
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:viewer_user_id]).to be_present
  end
end

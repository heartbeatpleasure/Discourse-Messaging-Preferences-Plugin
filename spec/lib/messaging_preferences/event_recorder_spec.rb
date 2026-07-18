# frozen_string_literal: true

RSpec.describe MessagingPreferences::EventRecorder do
  fab!(:user) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }

  def snapshot
    MessagingPreferences::PreferenceSnapshot.new(user)
  end

  it "records one event when preference content changes" do
    before_snapshot = snapshot
    before_snapshot.digest

    UserCustomField.create!(
      user_id: user.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )

    expect(
      described_class.record_preference_change!(
        user: user,
        before_snapshot: before_snapshot,
        after_snapshot: snapshot,
      ),
    ).to eq(true)

    event = MessagingPreferences::Event.last
    expect(event.event_type).to eq("preferences_created")
    expect(event.actor_user_id).to eq(user.id)
    expect(event.target_user_id).to eq(user.id)
  end

  it "does not record an event when content is unchanged" do
    UserCustomField.create!(
      user_id: user.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
    before_snapshot = snapshot
    before_snapshot.digest

    expect(
      described_class.record_preference_change!(
        user: user,
        before_snapshot: before_snapshot,
        after_snapshot: snapshot,
      ),
    ).to eq(false)
    expect(MessagingPreferences::Event.count).to eq(0)
  end

  it "records an acknowledgement only once for the current version" do
    digest = "b" * 64

    described_class.record_acknowledgement!(
      viewer: viewer,
      target: user,
      digest: digest,
      already_current: false,
    )
    described_class.record_acknowledgement!(
      viewer: viewer,
      target: user,
      digest: digest,
      already_current: true,
    )

    expect(MessagingPreferences::Event.where(event_type: "acknowledged").count).to eq(1)
  end
end

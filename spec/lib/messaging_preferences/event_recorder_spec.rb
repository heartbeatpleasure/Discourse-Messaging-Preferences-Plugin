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
  it "records an admin preference clear without storing preference text" do
    admin = Fabricate(:admin)
    UserCustomField.create!(
      user_id: user.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Private text",
    )
    before_snapshot = snapshot
    before_snapshot.digest

    expect(
      described_class.record_admin_preference_clear!(
        actor: admin,
        target: user,
        before_snapshot: before_snapshot,
      ),
    ).to eq(true)

    event = MessagingPreferences::Event.last
    expect(event.event_type).to eq("preferences_admin_cleared")
    expect(event.actor_user_id).to eq(admin.id)
    expect(event.target_user_id).to eq(user.id)
    expect(event.preferences_digest).to be_nil
    expect(event.attributes.values).not_to include("Private text")
  end

  it "records privacy-safe admin maintenance events" do
    admin = Fabricate(:admin)

    expect(described_class.record_admin_sitewide_cleanup!(actor: admin)).to eq(true)
    expect(
      described_class.record_admin_reset_all_acknowledgements!(
        actor: admin,
        removed_count: 3,
      ),
    ).to eq(true)
    expect(
      described_class.record_admin_reset_member_acknowledgements!(
        actor: admin,
        target: user,
        removed_count: 2,
      ),
    ).to eq(true)

    expect(
      MessagingPreferences::Event.order(:id).pluck(
        :event_type,
        :actor_user_id,
        :target_user_id,
      ),
    ).to eq(
      [
        ["admin_site_cleanup", admin.id, admin.id],
        ["admin_reset_all_acks", admin.id, admin.id],
        ["admin_reset_member_acks", admin.id, user.id],
      ],
    )
  end

  it "does not record acknowledgement resets that removed no relationships" do
    admin = Fabricate(:admin)

    expect(
      described_class.record_admin_reset_all_acknowledgements!(
        actor: admin,
        removed_count: 0,
      ),
    ).to eq(false)
    expect(
      described_class.record_admin_reset_member_acknowledgements!(
        actor: admin,
        target: user,
        removed_count: 0,
      ),
    ).to eq(false)
    expect(MessagingPreferences::Event.count).to eq(0)
  end
end

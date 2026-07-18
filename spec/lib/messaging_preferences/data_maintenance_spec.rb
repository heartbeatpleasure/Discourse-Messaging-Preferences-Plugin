# frozen_string_literal: true

RSpec.describe MessagingPreferences::DataMaintenance do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:target) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }

  before do
    SiteSetting.messaging_preferences_activity_retention_days = 365
  end

  def create_event(occurred_at:)
    MessagingPreferences::Event.create!(
      event_type: "preferences_updated",
      actor: target,
      target: target,
      preferences_digest: "a" * 64,
      occurred_at: occurred_at,
    )
  end

  it "removes activity older than the configured retention period" do
    create_event(occurred_at: 366.days.ago)
    recent = create_event(occurred_at: 364.days.ago)

    expect(described_class.purge_expired_events!).to eq(1)
    expect(MessagingPreferences::Event.pluck(:id)).to contain_exactly(recent.id)
  end

  it "keeps activity indefinitely when retention is zero" do
    SiteSetting.messaging_preferences_activity_retention_days = 0
    old = create_event(occurred_at: 10.years.ago)

    expect(described_class.purge_expired_events!).to eq(0)
    expect(MessagingPreferences::Event.exists?(old.id)).to eq(true)
  end

  it "keeps only the newest duplicate custom field without reviving an older value" do
    older = UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Older value",
    )
    newer = UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "   ",
    )

    result = described_class.cleanup!

    expect(result[:duplicate_custom_fields]).to eq(1)
    expect(result[:blank_custom_fields]).to eq(1)
    expect(UserCustomField.exists?(older.id)).to eq(false)
    expect(UserCustomField.exists?(newer.id)).to eq(false)
  end

  it "resets acknowledgement relationships involving one member" do
    other = Fabricate(:user)
    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: target,
      preferences_digest: "b" * 64,
      acknowledged_at: Time.zone.now,
    )
    MessagingPreferences::Acknowledgement.create!(
      viewer: target,
      target: other,
      preferences_digest: "c" * 64,
      acknowledged_at: Time.zone.now,
    )

    expect(described_class.reset_acknowledgements_for_user!(target)).to eq(2)
    expect(MessagingPreferences::Acknowledgement.count).to eq(0)
  end

  it "clears a member's preferences and received acknowledgements while recording an admin event" do
    UserCustomField.create!(
      user_id: target.id,
      name: MessagingPreferences::WORKS_WELL_FIELD,
      value: "Introduce yourself.",
    )
    MessagingPreferences::Acknowledgement.create!(
      viewer: viewer,
      target: target,
      preferences_digest: MessagingPreferences::PreferenceSnapshot.new(target).digest,
      acknowledged_at: Time.zone.now,
    )

    result = described_class.clear_preferences_for_user!(user: target, actor: admin)

    expect(result).to include(
      removed_fields: 1,
      removed_acknowledgements: 1,
      recorded_event: true,
    )
    expect(
      UserCustomField.where(user_id: target.id, name: MessagingPreferences::FIELD_NAMES),
    ).to be_empty
    expect(
      MessagingPreferences::Event.exists?(
        event_type: "preferences_admin_cleared",
        actor_user_id: admin.id,
        target_user_id: target.id,
      ),
    ).to eq(true)
  end
end

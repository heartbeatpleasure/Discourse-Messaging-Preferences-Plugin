# frozen_string_literal: true

class CreateMessagingPreferenceAcknowledgements < ActiveRecord::Migration[7.0]
  def change
    create_table :messaging_preference_acknowledgements do |t|
      t.integer :viewer_user_id, null: false
      t.integer :target_user_id, null: false
      t.string :preferences_digest, null: false, limit: 64
      t.datetime :acknowledged_at, null: false
      t.timestamps null: false
    end

    add_index :messaging_preference_acknowledgements,
              %i[viewer_user_id target_user_id],
              unique: true,
              name: "idx_messaging_pref_ack_viewer_target"

    add_index :messaging_preference_acknowledgements,
              :target_user_id,
              name: "idx_messaging_pref_ack_target"

    add_foreign_key :messaging_preference_acknowledgements,
                    :users,
                    column: :viewer_user_id,
                    on_delete: :cascade

    add_foreign_key :messaging_preference_acknowledgements,
                    :users,
                    column: :target_user_id,
                    on_delete: :cascade
  end
end

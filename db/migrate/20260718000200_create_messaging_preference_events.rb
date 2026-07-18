# frozen_string_literal: true

class CreateMessagingPreferenceEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :messaging_preference_events do |t|
      t.string :event_type, null: false, limit: 32
      t.integer :actor_user_id, null: false
      t.integer :target_user_id, null: false
      t.string :preferences_digest, limit: 64
      t.datetime :occurred_at, null: false
    end

    add_index :messaging_preference_events,
              :occurred_at,
              name: "idx_messaging_pref_events_occurred"
    add_index :messaging_preference_events,
              %i[event_type occurred_at],
              name: "idx_messaging_pref_events_type_time"
    add_index :messaging_preference_events,
              %i[actor_user_id occurred_at],
              name: "idx_messaging_pref_events_actor_time"
    add_index :messaging_preference_events,
              %i[target_user_id occurred_at],
              name: "idx_messaging_pref_events_target_time"

    add_foreign_key :messaging_preference_events,
                    :users,
                    column: :actor_user_id,
                    on_delete: :cascade
    add_foreign_key :messaging_preference_events,
                    :users,
                    column: :target_user_id,
                    on_delete: :cascade
  end
end

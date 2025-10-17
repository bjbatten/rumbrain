class CreateWorldsAndTurns < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto'

    create_table :worlds, id: :uuid do |t|
      t.string :seed
      t.string :difficulty
      t.jsonb :game_state, null: false, default: {}

      t.timestamps
    end

    add_index :worlds, :seed

    create_table :turns, id: :uuid do |t|
      t.uuid :world_id, null: false
      t.string :action, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :result, null: false, default: {}

      t.timestamps
    end

    add_index :turns, :world_id
    add_foreign_key :turns, :worlds, on_delete: :cascade
  end
end

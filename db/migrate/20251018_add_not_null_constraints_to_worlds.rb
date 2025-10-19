# db/migrate/20251018_add_not_null_constraints_to_worlds.rb
class AddNotNullConstraintsToWorlds < ActiveRecord::Migration[8.0]
  def up
    # Ensure a default for difficulty, then backfill any nils
    change_column_default :worlds, :difficulty, from: nil, to: "normal"
    World.where(difficulty: nil).update_all(difficulty: "normal")

    # Backfill save_code for any existing rows with NULL
    say_with_time "Backfilling save_code for worlds with NULL" do
      World.where(save_code: nil).find_each(batch_size: 500) do |w|
        # generate a unique, lowercase code (match your model behavior)
        code = nil
        loop do
          candidate = SecureRandom.base36(6).downcase
          break code = candidate unless World.exists?(save_code: candidate)
        end
        # use update_columns to skip validations/callbacks for speed
        w.update_columns(save_code: code)
      end
    end

    # Add unique index if not present
    add_index :worlds, :save_code, unique: true unless index_exists?(:worlds, :save_code, unique: true)

    # Now enforce NOT NULL at the DB level
    change_column_null :worlds, :difficulty, false
    change_column_null :worlds, :save_code, false
  end

  def down
    # Relax NOT NULLs
    change_column_null :worlds, :save_code, true
    change_column_null :worlds, :difficulty, true

    # Optional: drop unique index (leave it if you want to keep constraint even when null allowed)
    remove_index :worlds, :save_code if index_exists?(:worlds, :save_code)

    # Remove default
    change_column_default :worlds, :difficulty, from: "normal", to: nil
  end
end

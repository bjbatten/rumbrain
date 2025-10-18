class AddSaveCodeToWorlds < ActiveRecord::Migration[8.0]
  def change
    add_column :worlds, :save_code, :string
    add_index :worlds, :save_code, unique: true
  end
end

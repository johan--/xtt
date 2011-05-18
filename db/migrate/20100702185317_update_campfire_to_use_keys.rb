class UpdateCampfireToUseKeys < ActiveRecord::Migration
  def self.up
    remove_column :campfires, :password
    rename_column :campfires, :login, :key
  end

  def self.down
    rename_column :campfires, :key, :login
    add_column :campfires, :password
  end
end

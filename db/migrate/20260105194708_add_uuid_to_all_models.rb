# frozen_string_literal: true

# Add UUID fields to all models for use in public-facing URLs and APIs
# This improves security by preventing enumeration attacks and hiding record counts
class AddUuidToAllModels < ActiveRecord::Migration[8.1]
  def change
    # Main content models
    add_column :locations, :uuid, :string, limit: 36
    add_index :locations, :uuid, unique: true

    add_column :experiences, :uuid, :string, limit: 36
    add_index :experiences, :uuid, unique: true

    add_column :plans, :uuid, :string, limit: 36
    add_index :plans, :uuid, unique: true

    # User models
    add_column :users, :uuid, :string, limit: 36
    add_index :users, :uuid, unique: true

    add_column :curator_applications, :uuid, :string, limit: 36
    add_index :curator_applications, :uuid, unique: true

    # Review model
    add_column :reviews, :uuid, :string, limit: 36
    add_index :reviews, :uuid, unique: true

    # Category/Type models
    add_column :experience_categories, :uuid, :string, limit: 36
    add_index :experience_categories, :uuid, unique: true

    add_column :experience_types, :uuid, :string, limit: 36
    add_index :experience_types, :uuid, unique: true

    # Audio tour model
    add_column :audio_tours, :uuid, :string, limit: 36
    add_index :audio_tours, :uuid, unique: true

    # Generate UUIDs for existing records
    reversible do |dir|
      dir.up do
        # Generate UUIDs for all existing records
        %w[locations experiences plans users curator_applications reviews
           experience_categories experience_types audio_tours].each do |table|
          execute <<-SQL
            UPDATE #{table}
            SET uuid = gen_random_uuid()::text
            WHERE uuid IS NULL
          SQL
        end
      end
    end

    # Make UUID columns NOT NULL after populating
    change_column_null :locations, :uuid, false
    change_column_null :experiences, :uuid, false
    change_column_null :plans, :uuid, false
    change_column_null :users, :uuid, false
    change_column_null :curator_applications, :uuid, false
    change_column_null :reviews, :uuid, false
    change_column_null :experience_categories, :uuid, false
    change_column_null :experience_types, :uuid, false
    change_column_null :audio_tours, :uuid, false
  end
end

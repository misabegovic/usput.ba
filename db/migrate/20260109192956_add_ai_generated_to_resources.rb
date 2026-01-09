# frozen_string_literal: true

# This migration:
# 1. Adds ai_generated boolean to locations, experiences, and plans
# 2. Deletes ALL existing experiences and plans (as requested)
# 3. Marks all existing locations as AI generated
class AddAiGeneratedToResources < ActiveRecord::Migration[8.1]
  def up
    # Add ai_generated flag to all resource tables
    add_column :locations, :ai_generated, :boolean, default: true, null: false
    add_column :experiences, :ai_generated, :boolean, default: true, null: false
    add_column :plans, :ai_generated, :boolean, default: true, null: false

    # Add indexes for filtering
    add_index :locations, :ai_generated
    add_index :experiences, :ai_generated
    add_index :plans, :ai_generated

    # Delete all existing experiences and their associations
    # (plan_experiences will be deleted via CASCADE on plans, and experience_locations via CASCADE)
    execute <<-SQL
      -- First delete plan_experiences to clean up associations
      DELETE FROM plan_experiences;

      -- Delete experience_locations to clean up associations
      DELETE FROM experience_locations;

      -- Delete all experiences
      DELETE FROM experiences;

      -- Delete all plans (only AI-generated public plans, not user plans)
      DELETE FROM plans WHERE user_id IS NULL;
    SQL

    # Mark all remaining locations as AI generated (default is already true, but be explicit)
    execute "UPDATE locations SET ai_generated = true"
  end

  def down
    remove_index :locations, :ai_generated
    remove_index :experiences, :ai_generated
    remove_index :plans, :ai_generated

    remove_column :locations, :ai_generated
    remove_column :experiences, :ai_generated
    remove_column :plans, :ai_generated

    # Note: Deleted data cannot be restored
  end
end

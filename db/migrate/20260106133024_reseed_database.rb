class ReseedDatabase < ActiveRecord::Migration[8.0]
  def up
    # Clear all existing data in correct order (respecting foreign keys)
    say_with_time "Clearing existing data..." do
      # Clear join tables first
      execute "TRUNCATE TABLE experience_locations RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE experience_category_types RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE location_category_assignments RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE location_experience_types RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE plan_experiences RESTART IDENTITY CASCADE"

      # Clear dependent tables
      execute "TRUNCATE TABLE reviews RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE audio_tours RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE translations RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE browses RESTART IDENTITY CASCADE"

      # Clear main tables
      execute "TRUNCATE TABLE experiences RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE locations RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE plans RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE experience_categories RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE experience_types RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE location_categories RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE locales RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE settings RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE users RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE curator_applications RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE ai_generations RESTART IDENTITY CASCADE"

      # Clear Active Storage
      execute "TRUNCATE TABLE active_storage_attachments RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE active_storage_variant_records RESTART IDENTITY CASCADE"
      execute "TRUNCATE TABLE active_storage_blobs RESTART IDENTITY CASCADE"
    end

    # Run seeds
    say_with_time "Running seeds..." do
      Rails.application.load_seed
    end
  end

  def down
    # This migration is not reversible
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse database reseed"
  end
end

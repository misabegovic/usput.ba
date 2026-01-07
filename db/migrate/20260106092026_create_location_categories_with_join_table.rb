class CreateLocationCategoriesWithJoinTable < ActiveRecord::Migration[8.1]
  def change
    # Create location_categories table
    create_table :location_categories do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :icon
      t.integer :position, default: 0
      t.boolean :active, default: true, null: false
      t.string :uuid, null: false

      t.timestamps
    end

    add_index :location_categories, :key, unique: true
    add_index :location_categories, :uuid, unique: true
    add_index :location_categories, :active
    add_index :location_categories, :position

    # Create join table for many-to-many relationship
    create_table :location_category_assignments do |t|
      t.references :location, null: false, foreign_key: true
      t.references :location_category, null: false, foreign_key: true
      t.boolean :primary, default: false  # Mark the primary category for display purposes

      t.timestamps
    end

    # Composite unique index to prevent duplicates
    add_index :location_category_assignments, [:location_id, :location_category_id],
              unique: true, name: 'idx_loc_cat_assignments_unique'

    # Migrate existing location_type enum values to location_categories
    reversible do |dir|
      dir.up do
        # Create default categories based on existing enum values plus new ones
        categories = [
          { key: 'attraction', name: 'Attraction', icon: 'map-pin', position: 1 },
          { key: 'restaurant', name: 'Restaurant & Café', icon: 'utensils', position: 2 },
          { key: 'accommodation', name: 'Accommodation', icon: 'bed', position: 3 },
          { key: 'guide', name: 'Local Guide', icon: 'user', position: 4 },
          { key: 'business', name: 'Local Business', icon: 'briefcase', position: 5 },
          { key: 'artisan', name: 'Artisan & Craftsman', icon: 'hammer', position: 6 },
          { key: 'museum', name: 'Museum & Gallery', icon: 'landmark', position: 7 },
          { key: 'nature', name: 'Nature & Park', icon: 'trees', position: 8 },
          { key: 'religious', name: 'Religious Site', icon: 'church', position: 9 },
          { key: 'historical', name: 'Historical Site', icon: 'scroll', position: 10 },
          { key: 'entertainment', name: 'Entertainment', icon: 'ticket', position: 11 },
          { key: 'shopping', name: 'Shopping', icon: 'shopping-bag', position: 12 },
          { key: 'transport', name: 'Transport Hub', icon: 'bus', position: 13 },
          { key: 'viewpoint', name: 'Viewpoint', icon: 'eye', position: 14 },
          { key: 'beach', name: 'Beach', icon: 'umbrella-beach', position: 15 },
          { key: 'sports', name: 'Sports & Recreation', icon: 'dumbbell', position: 16 },
          { key: 'wellness', name: 'Wellness & Spa', icon: 'spa', position: 17 },
          { key: 'nightlife', name: 'Nightlife', icon: 'moon', position: 18 },
          { key: 'market', name: 'Market & Bazaar', icon: 'store', position: 19 },
          { key: 'cultural', name: 'Cultural Site', icon: 'theater-masks', position: 20 },
          { key: 'other', name: 'Other', icon: 'circle', position: 100 }
        ]

        categories.each do |cat|
          execute <<-SQL
            INSERT INTO location_categories (key, name, icon, position, active, uuid, created_at, updated_at)
            VALUES ('#{cat[:key]}', '#{cat[:name]}', '#{cat[:icon]}', #{cat[:position]}, true, '#{SecureRandom.uuid}', NOW(), NOW())
          SQL
        end

        # Map old location_type enum values to new categories
        # place (0) -> attraction, guide (1) -> guide, business (2) -> business,
        # restaurant (3) -> restaurant, artisan (4) -> artisan, accommodation (5) -> accommodation
        mapping = {
          0 => 'attraction',  # place
          1 => 'guide',
          2 => 'business',
          3 => 'restaurant',
          4 => 'artisan',
          5 => 'accommodation'
        }

        mapping.each do |old_type, new_key|
          execute <<-SQL
            INSERT INTO location_category_assignments (location_id, location_category_id, "primary", created_at, updated_at)
            SELECT l.id,
                   (SELECT id FROM location_categories WHERE key = '#{new_key}'),
                   true,
                   NOW(),
                   NOW()
            FROM locations l
            WHERE l.location_type = #{old_type}
              AND NOT EXISTS (
                SELECT 1 FROM location_category_assignments lca
                WHERE lca.location_id = l.id
                  AND lca.location_category_id = (SELECT id FROM location_categories WHERE key = '#{new_key}')
              )
          SQL
        end
      end
    end
  end
end

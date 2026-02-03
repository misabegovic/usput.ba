class MigrateLocationTypeToCategories < ActiveRecord::Migration[8.1]
  def up
    # 1. Create default LocationCategory records
    categories = [
      { key: 'place', name: 'Place', icon: 'map-pin', position: 1 },
      { key: 'attraction', name: 'Attraction', icon: 'map-pin', position: 2 },
      { key: 'restaurant', name: 'Restaurant & Café', icon: 'utensils', position: 3 },
      { key: 'accommodation', name: 'Accommodation', icon: 'bed', position: 4 },
      { key: 'guide', name: 'Local Guide', icon: 'user', position: 5 },
      { key: 'business', name: 'Local Business', icon: 'briefcase', position: 6 },
      { key: 'artisan', name: 'Artisan & Craftsman', icon: 'hammer', position: 7 },
      { key: 'museum', name: 'Museum & Gallery', icon: 'landmark', position: 8 },
      { key: 'nature', name: 'Nature & Park', icon: 'trees', position: 9 },
      { key: 'religious', name: 'Religious Site', icon: 'church', position: 10 },
      { key: 'historical', name: 'Historical Site', icon: 'scroll', position: 11 },
      { key: 'entertainment', name: 'Entertainment', icon: 'ticket', position: 12 },
      { key: 'shopping', name: 'Shopping', icon: 'shopping-bag', position: 13 },
      { key: 'transport', name: 'Transport Hub', icon: 'bus', position: 14 },
      { key: 'viewpoint', name: 'Viewpoint', icon: 'eye', position: 15 },
      { key: 'beach', name: 'Beach', icon: 'umbrella-beach', position: 16 },
      { key: 'sports', name: 'Sports & Recreation', icon: 'dumbbell', position: 17 },
      { key: 'wellness', name: 'Wellness & Spa', icon: 'spa', position: 18 },
      { key: 'nightlife', name: 'Nightlife', icon: 'moon', position: 19 },
      { key: 'market', name: 'Market & Bazaar', icon: 'store', position: 20 },
      { key: 'cultural', name: 'Cultural Site', icon: 'theater-masks', position: 21 },
      { key: 'other', name: 'Other', icon: 'circle', position: 100 }
    ]

    categories.each do |cat|
      # Use find_or_create to avoid duplicates if migration is re-run
      execute <<-SQL
        INSERT INTO location_categories (key, name, icon, position, active, uuid, created_at, updated_at)
        SELECT '#{cat[:key]}', '#{cat[:name]}', '#{cat[:icon]}', #{cat[:position]}, true, '#{SecureRandom.uuid}', NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM location_categories WHERE key = '#{cat[:key]}')
      SQL
    end

    # 2. Migrate existing location_type enum values to location_categories
    # Map: place (0) -> place, guide (1) -> guide, business (2) -> business,
    # restaurant (3) -> restaurant, artisan (4) -> artisan, accommodation (5) -> accommodation
    mapping = {
      0 => 'place',
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

    # 3. Remove location_type column
    remove_column :locations, :location_type, :integer
  end

  def down
    # Add back location_type column
    add_column :locations, :location_type, :integer, default: 0

    # Map categories back to enum
    mapping = {
      'place' => 0,
      'guide' => 1,
      'business' => 2,
      'restaurant' => 3,
      'artisan' => 4,
      'accommodation' => 5
    }

    mapping.each do |category_key, enum_value|
      execute <<-SQL
        UPDATE locations l
        SET location_type = #{enum_value}
        FROM location_category_assignments lca
        JOIN location_categories lc ON lc.id = lca.location_category_id
        WHERE lca.location_id = l.id
          AND lc.key = '#{category_key}'
          AND lca.primary = true
      SQL
    end
  end
end

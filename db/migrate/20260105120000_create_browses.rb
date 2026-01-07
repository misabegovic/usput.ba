class CreateBrowses < ActiveRecord::Migration[8.1]
  def change
    create_table :browses do |t|
      # Polymorphic reference to the source model (Location, Experience, Plan)
      t.references :browsable, polymorphic: true, null: false

      # Denormalized fields for display and filtering
      t.string :title, null: false
      t.text :description
      t.string :browsable_subtype  # location_type, experience_category, etc.
      t.references :city, foreign_key: true

      # For geo-based search
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6

      # For filtering
      t.decimal :average_rating, precision: 3, scale: 2, default: 0.0
      t.integer :reviews_count, default: 0

      # PostgreSQL full-text search vector
      t.virtual :searchable, type: :tsvector, as: <<~SQL.squish, stored: true
        setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('simple', coalesce(description, '')), 'B')
      SQL

      t.timestamps
    end

    # Index for polymorphic lookup - ensures uniqueness per browsable record
    add_index :browses, [:browsable_type, :browsable_id], unique: true

    # Index for full-text search using GIN
    add_index :browses, :searchable, using: :gin

    # Index for filtering by type
    add_index :browses, :browsable_type

    # Index for filtering by subtype
    add_index :browses, :browsable_subtype

    # Index for geo queries (lat/lng bounding box)
    add_index :browses, [:lat, :lng]

    # Index for rating-based sorting
    add_index :browses, :average_rating

    # Index for reviews count sorting
    add_index :browses, :reviews_count
  end
end

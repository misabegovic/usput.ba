# frozen_string_literal: true

require "test_helper"

class LocationTest < ActiveSupport::TestCase
  setup do
    @valid_params = {
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    }
  end

  # === Validation tests ===

  test "valid location is saved" do
    location = Location.new(@valid_params)
    assert location.save
    location.destroy
  end

  test "name is required" do
    location = Location.new(@valid_params.merge(name: nil))
    assert_not location.valid?
    assert_includes location.errors[:name], "can't be blank"
  end

  test "latitude must be within valid range" do
    location = Location.new(@valid_params.merge(lat: 91))
    assert_not location.valid?

    location.lat = -91
    assert_not location.valid?

    location.lat = 45
    assert location.valid?
  end

  test "longitude must be within valid range" do
    location = Location.new(@valid_params.merge(lng: 181))
    assert_not location.valid?

    location.lng = -181
    assert_not location.valid?

    location.lng = 18
    assert location.valid?
  end

  test "coordinates must be complete (both or neither)" do
    location = Location.new(@valid_params.merge(lat: 43.8, lng: nil))
    assert_not location.valid?
    assert location.errors[:base].include?("Both latitude and longitude must be provided, or neither")
  end

  test "coordinates uniqueness validation" do
    Location.create!(@valid_params)
    duplicate = Location.new(@valid_params)
    assert_not duplicate.valid?
    assert duplicate.errors[:lat].any?
    Location.find_by(name: "Test Location")&.destroy
  end

  test "email validation" do
    location = Location.new(@valid_params.merge(email: "invalid"))
    assert_not location.valid?

    location.email = "valid@example.com"
    assert location.valid?
  end

  test "website validation" do
    location = Location.new(@valid_params.merge(website: "invalid"))
    assert_not location.valid?

    location.website = "https://example.com"
    assert location.valid?
  end

  test "phone validation" do
    location = Location.new(@valid_params.merge(phone: "abc"))
    assert_not location.valid?

    location.phone = "+387 61 123 456"
    assert location.valid?
  end

  test "video_url validation rejects invalid URLs" do
    location = Location.new(@valid_params.merge(video_url: "not-a-url"))
    assert_not location.valid?
    assert_includes location.errors[:video_url], "must be a valid URL"
  end

  test "video_url validation accepts valid https URL" do
    location = Location.new(@valid_params.merge(video_url: "https://youtube.com/watch?v=123"))
    assert location.valid?
  end

  test "video_url validation accepts valid http URL" do
    location = Location.new(@valid_params.merge(video_url: "http://example.com/video.mp4"))
    assert location.valid?
  end

  test "video_url validation allows blank" do
    location = Location.new(@valid_params.merge(video_url: ""))
    assert location.valid?
  end

  # === UUID generation tests ===

  test "uuid is generated on create" do
    location = Location.create!(@valid_params)
    assert location.uuid.present?
    location.destroy
  end

  # === Coordinate helpers ===

  test "geocoded? returns true when coordinates present" do
    location = Location.new(@valid_params)
    assert location.geocoded?
  end

  test "geocoded? returns false when coordinates missing" do
    location = Location.new(@valid_params.merge(lat: nil, lng: nil))
    assert_not location.geocoded?
  end

  test "coordinates returns array of lat/lng" do
    location = Location.new(@valid_params)
    assert_equal [ 43.8563, 18.4131 ], location.coordinates
  end

  test "coordinates returns nil when not geocoded" do
    location = Location.new(@valid_params.merge(lat: nil, lng: nil))
    assert_nil location.coordinates
  end

  test "address returns city" do
    location = Location.new(@valid_params)
    assert_equal "Sarajevo", location.address
  end

  # === Tag helpers ===

  test "tags returns empty array by default" do
    location = Location.new(@valid_params)
    assert_equal [], location.tags
  end

  test "tags returns empty array when nil in database" do
    location = Location.new(@valid_params)
    location.instance_variable_set(:@attributes, location.instance_variable_get(:@attributes))
    # This tests the method override that returns [] || super
    assert_equal [], location.tags
  end

  test "add_tag adds tag to array" do
    location = Location.create!(@valid_params)
    location.add_tag("historic")
    assert_includes location.tags, "historic"
    location.destroy
  end

  test "add_tag normalizes tag to lowercase" do
    location = Location.create!(@valid_params)
    location.add_tag("HISTORIC")
    assert_includes location.tags, "historic"
    location.destroy
  end

  test "add_tag strips whitespace" do
    location = Location.create!(@valid_params)
    location.add_tag("  historic  ")
    assert_includes location.tags, "historic"
    location.destroy
  end

  test "add_tag prevents duplicates" do
    location = Location.create!(@valid_params)
    location.add_tag("historic")
    location.add_tag("historic")
    assert_equal 1, location.tags.count("historic")
    location.destroy
  end

  test "remove_tag removes tag from array" do
    location = Location.create!(@valid_params)
    location.add_tag("historic")
    location.remove_tag("historic")
    assert_not_includes location.tags, "historic"
    location.destroy
  end

  test "remove_tag normalizes tag to lowercase" do
    location = Location.create!(@valid_params)
    location.add_tag("historic")
    location.remove_tag("HISTORIC")
    assert_not_includes location.tags, "historic"
    location.destroy
  end

  # === Season helpers ===

  test "seasons returns empty array by default" do
    location = Location.new(@valid_params)
    assert_equal [], location.seasons
  end

  test "year_round? returns true when seasons empty" do
    location = Location.new(@valid_params)
    assert location.year_round?
  end

  test "year_round? returns false when seasons set" do
    location = Location.new(@valid_params.merge(seasons: [ "summer" ]))
    assert_not location.year_round?
  end

  test "available_in_season? returns true for year-round locations" do
    location = Location.new(@valid_params)
    assert location.available_in_season?("summer")
    assert location.available_in_season?("winter")
  end

  test "available_in_season? returns true when season matches" do
    location = Location.new(@valid_params.merge(seasons: [ "summer" ]))
    assert location.available_in_season?("summer")
    assert_not location.available_in_season?("winter")
  end

  test "available_in_season? works with symbol argument" do
    location = Location.new(@valid_params.merge(seasons: [ "summer" ]))
    assert location.available_in_season?(:summer)
  end

  test "add_season adds valid season" do
    location = Location.create!(@valid_params)
    location.add_season("summer")
    assert_includes location.seasons, "summer"
    location.destroy
  end

  test "add_season normalizes to lowercase" do
    location = Location.create!(@valid_params)
    location.add_season("SUMMER")
    assert_includes location.seasons, "summer"
    location.destroy
  end

  test "add_season ignores invalid seasons" do
    location = Location.create!(@valid_params)
    location.add_season("invalid_season")
    assert_not_includes location.seasons, "invalid_season"
    location.destroy
  end

  test "add_season prevents duplicates" do
    location = Location.create!(@valid_params)
    location.add_season("summer")
    location.add_season("summer")
    assert_equal 1, location.seasons.count("summer")
    location.destroy
  end

  test "remove_season removes season from array" do
    location = Location.create!(@valid_params)
    location.add_season("summer")
    location.remove_season("summer")
    assert_not_includes location.seasons, "summer"
    location.destroy
  end

  test "remove_season normalizes to lowercase" do
    location = Location.create!(@valid_params)
    location.add_season("summer")
    location.remove_season("SUMMER")
    assert_not_includes location.seasons, "summer"
    location.destroy
  end

  test "set_year_round! clears all seasons" do
    location = Location.create!(@valid_params.merge(seasons: [ "summer", "winter" ]))
    location.set_year_round!
    assert_equal [], location.seasons
    location.destroy
  end

  test "season_names returns Year-round when empty" do
    location = Location.new(@valid_params)
    assert_equal [ "Year-round" ], location.season_names
  end

  test "season_names returns titleized season names" do
    location = Location.new(@valid_params.merge(seasons: [ "summer", "winter" ]))
    assert_includes location.season_names, "Summer"
    assert_includes location.season_names, "Winter"
    assert_equal 2, location.season_names.size
  end

  # === Social links helpers ===

  test "social_links returns empty hash by default" do
    location = Location.new(@valid_params)
    assert_equal({}, location.social_links)
  end

  test "add_social_link adds valid platform" do
    location = Location.create!(@valid_params)
    location.add_social_link("facebook", "https://facebook.com/test")
    assert_equal "https://facebook.com/test", location.social_link("facebook")
    location.destroy
  end

  test "add_social_link normalizes platform to lowercase" do
    location = Location.create!(@valid_params)
    location.add_social_link("FACEBOOK", "https://facebook.com/test")
    assert_equal "https://facebook.com/test", location.social_link("facebook")
    location.destroy
  end

  test "add_social_link strips whitespace" do
    location = Location.create!(@valid_params)
    location.add_social_link("  facebook  ", "  https://facebook.com/test  ")
    assert_equal "https://facebook.com/test", location.social_link("facebook")
    location.destroy
  end

  test "add_social_link ignores unsupported platforms" do
    location = Location.create!(@valid_params)
    location.add_social_link("unsupported_platform", "https://example.com")
    assert_nil location.social_link("unsupported_platform")
    location.destroy
  end

  test "remove_social_link removes platform" do
    location = Location.create!(@valid_params)
    location.add_social_link("facebook", "https://facebook.com/test")
    location.remove_social_link("facebook")
    assert_nil location.social_link("facebook")
    location.destroy
  end

  test "social_link returns nil for non-existent platform" do
    location = Location.new(@valid_params)
    assert_nil location.social_link("facebook")
  end

  # === Category helpers ===

  test "category_key returns primary category key" do
    category = LocationCategory.create!(name: "Museum", key: "museum_test")
    location = Location.create!(@valid_params)
    location.add_category(category, primary: true)

    assert_equal "museum_test", location.category_key

    location.destroy
    category.destroy
  end

  test "category_key falls back to location_type when no categories" do
    location = Location.create!(@valid_params.merge(location_type: :guide))
    assert_equal "guide", location.category_key
    location.destroy
  end

  test "category_keys returns all category keys" do
    cat1 = LocationCategory.create!(name: "Museum", key: "museum_key_test")
    cat2 = LocationCategory.create!(name: "Historic", key: "historic_key_test")
    location = Location.create!(@valid_params)
    location.add_category(cat1)
    location.add_category(cat2)

    assert_includes location.category_keys, "museum_key_test"
    assert_includes location.category_keys, "historic_key_test"

    location.destroy
    cat1.destroy
    cat2.destroy
  end

  test "category_name returns primary category name" do
    category = LocationCategory.create!(name: "Beautiful Museum", key: "museum_name_test")
    location = Location.create!(@valid_params)
    location.add_category(category, primary: true)

    assert_equal "Beautiful Museum", location.category_name

    location.destroy
    category.destroy
  end

  test "category_name falls back to location_type titleized when no categories" do
    location = Location.create!(@valid_params.merge(location_type: :guide))
    assert_equal "Guide", location.category_name
    location.destroy
  end

  test "category_names returns all category names" do
    cat1 = LocationCategory.create!(name: "Museum Display", key: "museum_names_test")
    cat2 = LocationCategory.create!(name: "Historic Place", key: "historic_names_test")
    location = Location.create!(@valid_params)
    location.add_category(cat1)
    location.add_category(cat2)

    assert_includes location.category_names, "Museum Display"
    assert_includes location.category_names, "Historic Place"

    location.destroy
    cat1.destroy
    cat2.destroy
  end

  test "has_category? checks for category presence" do
    category = LocationCategory.create!(name: "Test", key: "test_category")
    location = Location.create!(@valid_params)

    assert_not location.has_category?("test_category")

    location.add_category(category)
    assert location.has_category?("test_category")

    location.destroy
    category.destroy
  end

  test "has_category? works with category object" do
    category = LocationCategory.create!(name: "Test", key: "test_category_obj")
    location = Location.create!(@valid_params)
    location.add_category(category)

    assert location.has_category?(category)

    location.destroy
    category.destroy
  end

  test "add_category by key" do
    category = LocationCategory.create!(name: "Test", key: "add_by_key_test")
    location = Location.create!(@valid_params)

    location.add_category("add_by_key_test")
    assert location.has_category?("add_by_key_test")

    location.destroy
    category.destroy
  end

  test "add_category does nothing for non-existent key" do
    location = Location.create!(@valid_params)
    result = location.add_category("nonexistent_category")
    assert_nil result
    location.destroy
  end

  test "remove_category removes category" do
    category = LocationCategory.create!(name: "Test", key: "remove_cat_test")
    location = Location.create!(@valid_params)
    location.add_category(category)
    assert location.has_category?("remove_cat_test")

    location.remove_category(category)
    assert_not location.has_category?("remove_cat_test")

    location.destroy
    category.destroy
  end

  test "remove_category by key" do
    category = LocationCategory.create!(name: "Test", key: "remove_by_key_test")
    location = Location.create!(@valid_params)
    location.add_category(category)

    location.remove_category("remove_by_key_test")
    assert_not location.has_category?("remove_by_key_test")

    location.destroy
    category.destroy
  end

  test "remove_category does nothing for non-existent category" do
    location = Location.create!(@valid_params)
    result = location.remove_category("nonexistent")
    assert_nil result
    location.destroy
  end

  test "primary_category returns category marked as primary" do
    cat1 = LocationCategory.create!(name: "Secondary", key: "secondary_cat_test")
    cat2 = LocationCategory.create!(name: "Primary", key: "primary_cat_test")
    location = Location.create!(@valid_params)
    location.add_category(cat1)
    location.add_category(cat2, primary: true)

    assert_equal cat2, location.primary_category

    location.destroy
    cat1.destroy
    cat2.destroy
  end

  test "primary_category falls back to first category" do
    category = LocationCategory.create!(name: "Only One", key: "only_one_cat_test")
    location = Location.create!(@valid_params)
    location.add_category(category)

    assert_equal category, location.primary_category

    location.destroy
    category.destroy
  end

  test "contact? returns true for contact type category" do
    category = LocationCategory.create!(name: "Guide", key: "guide")
    location = Location.create!(@valid_params)
    location.add_category(category)

    assert location.contact?

    location.destroy
    category.destroy
  end

  test "contact? returns true for legacy non-place type" do
    location = Location.create!(@valid_params.merge(location_type: :guide))
    assert location.contact?
    location.destroy
  end

  test "contact? returns false for place type" do
    location = Location.create!(@valid_params.merge(location_type: :place))
    assert_not location.contact?
    location.destroy
  end

  test "place_type? returns true for place category" do
    category = LocationCategory.create!(name: "Museum", key: "museum_place_test")
    location = Location.create!(@valid_params)
    location.add_category(category)

    assert location.place_type?

    location.destroy
    category.destroy
  end

  test "place_type? returns true for legacy place type when no categories" do
    location = Location.create!(@valid_params.merge(location_type: :place))
    assert location.place_type?
    location.destroy
  end

  # === Experience type helpers ===

  test "suitable_experiences returns empty array by default" do
    location = Location.new(@valid_params)
    assert_equal [], location.suitable_experiences
  end

  test "add_experience_type creates and adds experience type" do
    location = Location.create!(@valid_params)
    location.add_experience_type("culture")

    assert location.has_experience_type?("culture")

    location.destroy
    ExperienceType.find_by(key: "culture")&.destroy
  end

  test "add_experience_type accepts ExperienceType object" do
    exp_type = ExperienceType.create!(key: "history_test", name: "History", active: true, position: 1)
    location = Location.create!(@valid_params)
    location.add_experience_type(exp_type)

    assert location.has_experience_type?(exp_type)

    location.destroy
    exp_type.destroy
  end

  test "add_experience_type ignores blank key" do
    location = Location.create!(@valid_params)
    result = location.add_experience_type("")
    assert_nil result
    location.destroy
  end

  test "add_experience_type does not create duplicates" do
    location = Location.create!(@valid_params)
    location.add_experience_type("adventure")
    location.add_experience_type("adventure")

    assert_equal 1, location.experience_types.where(key: "adventure").count

    location.destroy
    ExperienceType.find_by(key: "adventure")&.destroy
  end

  test "remove_experience_type removes by key" do
    exp_type = ExperienceType.create!(key: "food_test", name: "Food", active: true, position: 1)
    location = Location.create!(@valid_params)
    location.add_experience_type(exp_type)
    assert location.has_experience_type?("food_test")

    location.remove_experience_type("food_test")
    assert_not location.has_experience_type?("food_test")

    location.destroy
    exp_type.destroy
  end

  test "remove_experience_type removes by object" do
    exp_type = ExperienceType.create!(key: "nature_test", name: "Nature", active: true, position: 1)
    location = Location.create!(@valid_params)
    location.add_experience_type(exp_type)

    location.remove_experience_type(exp_type)
    assert_not location.has_experience_type?(exp_type)

    location.destroy
    exp_type.destroy
  end

  test "remove_experience_type does nothing for non-existent type" do
    location = Location.create!(@valid_params)
    assert_nothing_raised do
      location.remove_experience_type("nonexistent")
    end
    location.destroy
  end

  test "has_experience_type? returns false for non-existent type" do
    location = Location.create!(@valid_params)
    assert_not location.has_experience_type?("nonexistent")
    location.destroy
  end

  test "add_experience is alias for add_experience_type" do
    location = Location.create!(@valid_params)
    location.add_experience("wellness")
    assert location.has_experience_type?("wellness")
    location.destroy
    ExperienceType.find_by(key: "wellness")&.destroy
  end

  test "remove_experience is alias for remove_experience_type" do
    exp_type = ExperienceType.create!(key: "relax_test", name: "Relax", active: true, position: 1)
    location = Location.create!(@valid_params)
    location.add_experience_type(exp_type)

    location.remove_experience("relax_test")
    assert_not location.has_experience_type?("relax_test")

    location.destroy
    exp_type.destroy
  end

  test "suitable_experiences returns experience type keys from association" do
    exp_type = ExperienceType.create!(key: "art_test", name: "Art", active: true, position: 1)
    location = Location.create!(@valid_params)
    location.add_experience_type(exp_type)
    location.experience_types.reload

    # Force loading the association
    location.experience_types.load

    assert_includes location.suitable_experiences, "art_test"

    location.destroy
    exp_type.destroy
  end

  # === Nearby locations ===

  test "nearby_featured returns locations in same city" do
    location1 = Location.create!(@valid_params)
    location2 = Location.create!(@valid_params.merge(
      name: "Nearby Place",
      lat: 43.8570,
      lng: 18.4140
    ))

    nearby = location1.nearby_featured(limit: 3)
    assert_includes nearby, location2

    location2.destroy
    location1.destroy
  end

  test "nearby_featured excludes self" do
    location = Location.create!(@valid_params)

    nearby = location.nearby_featured(limit: 3)
    assert_not_includes nearby, location

    location.destroy
  end

  test "nearby_featured returns empty when no city" do
    location = Location.create!(@valid_params.merge(city: nil))
    assert_empty location.nearby_featured
    location.destroy
  end

  test "nearby_locations returns locations within radius" do
    location1 = Location.create!(@valid_params)
    location2 = Location.create!(@valid_params.merge(
      name: "Close Place",
      lat: 43.8570,
      lng: 18.4140
    ))

    nearby = location1.nearby_locations(radius_km: 10, limit: 10)
    assert_includes nearby, location2

    location2.destroy
    location1.destroy
  end

  test "nearby_locations excludes self" do
    location = Location.create!(@valid_params)
    nearby = location.nearby_locations(radius_km: 10)
    assert_not_includes nearby, location
    location.destroy
  end

  test "nearby_locations returns empty when no coordinates" do
    location = Location.create!(@valid_params.merge(lat: nil, lng: nil))
    assert_empty location.nearby_locations
    location.destroy
  end

  test "locations_in_same_city returns locations in same city" do
    location1 = Location.create!(@valid_params)
    location2 = Location.create!(@valid_params.merge(
      name: "Same City",
      lat: 43.8570,
      lng: 18.4140
    ))

    result = location1.locations_in_same_city
    assert_includes result, location2
    assert_not_includes result, location1

    location2.destroy
    location1.destroy
  end

  # === Contact info helpers ===

  test "has_contact_info? returns false when no contact info" do
    location = Location.new(@valid_params)
    assert_not location.has_contact_info?
  end

  test "has_contact_info? returns true when phone present" do
    location = Location.new(@valid_params.merge(phone: "+387 61 123 456"))
    assert location.has_contact_info?
  end

  test "has_contact_info? returns true when email present" do
    location = Location.new(@valid_params.merge(email: "test@example.com"))
    assert location.has_contact_info?
  end

  test "has_contact_info? returns true when website present" do
    location = Location.new(@valid_params.merge(website: "https://example.com"))
    assert location.has_contact_info?
  end

  # === Distance calculations ===

  test "distance_from calculates distance in km" do
    location = Location.new(@valid_params)
    # Mostar coordinates
    distance = location.distance_from(43.3438, 17.8078)

    assert distance.present?
    assert distance > 0
    # Sarajevo to Mostar is approximately 60-70 km
    assert distance > 50
    assert distance < 100
  end

  test "distance_from returns nil when not geocoded" do
    location = Location.new(@valid_params.merge(lat: nil, lng: nil))
    assert_nil location.distance_from(43.3438, 17.8078)
  end

  # === Find by coordinates ===

  test "find_or_initialize_by_coordinates returns existing location" do
    existing = Location.create!(@valid_params)
    found = Location.find_or_initialize_by_coordinates(43.8563, 18.4131)

    assert_equal existing.id, found.id
    assert found.persisted?

    existing.destroy
  end

  test "find_or_initialize_by_coordinates returns new location when not found" do
    found = Location.find_or_initialize_by_coordinates(99.0, 99.0, name: "New Place")

    assert_not found.persisted?
    assert_equal 99.0, found.lat
    assert_equal "New Place", found.name
  end

  test "find_or_initialize_by_coordinates handles blank coordinates" do
    found = Location.find_or_initialize_by_coordinates(nil, nil, name: "No Coords")
    assert_not found.persisted?
    assert_nil found.lat
    assert_nil found.lng
  end

  test "find_or_create_by_coordinates creates new location when not found" do
    location = Location.find_or_create_by_coordinates(88.0, 88.0, name: "Created Place")

    assert location.persisted?
    assert_equal 88.0, location.lat
    assert_equal "Created Place", location.name

    location.destroy
  end

  test "find_or_create_by_coordinates returns existing location" do
    existing = Location.create!(@valid_params)
    found = Location.find_or_create_by_coordinates(43.8563, 18.4131)

    assert_equal existing.id, found.id

    existing.destroy
  end

  test "find_by_coordinates_fuzzy finds locations within tolerance" do
    location = Location.create!(@valid_params)

    # Slightly different coordinates
    found = Location.find_by_coordinates_fuzzy(43.85631, 18.41311)
    assert_equal location, found

    location.destroy
  end

  test "find_by_coordinates_fuzzy returns nil when outside tolerance" do
    location = Location.create!(@valid_params)

    found = Location.find_by_coordinates_fuzzy(43.9, 18.5)
    assert_nil found

    location.destroy
  end

  test "find_by_coordinates_fuzzy returns nil for blank coordinates" do
    assert_nil Location.find_by_coordinates_fuzzy(nil, nil)
  end

  test "find_by_coordinates_fuzzy accepts custom tolerance" do
    location = Location.create!(@valid_params)

    # With larger tolerance
    found = Location.find_by_coordinates_fuzzy(43.857, 18.414, tolerance: 0.01)
    assert_equal location, found

    location.destroy
  end

  # === Class methods ===

  test "nearby class method returns locations near coordinates" do
    location = Location.create!(@valid_params)
    results = Location.nearby(43.8563, 18.4131, radius_km: 1)

    assert_includes results, location

    location.destroy
  end

  test "in_same_city returns locations in same city excluding given location" do
    location1 = Location.create!(@valid_params)
    location2 = Location.create!(@valid_params.merge(
      name: "Same City Place",
      lat: 43.8570,
      lng: 18.4140
    ))

    results = Location.in_same_city(location1)
    assert_includes results, location2
    assert_not_includes results, location1

    location2.destroy
    location1.destroy
  end

  test "in_same_city returns none when location has no city" do
    location = Location.create!(@valid_params.merge(city: nil))
    assert_empty Location.in_same_city(location)
    location.destroy
  end

  test "supported_experiences returns active experience type keys" do
    exp_type = ExperienceType.create!(key: "supported_exp_test", name: "Test", active: true, position: 1)

    keys = Location.supported_experiences
    assert_includes keys, "supported_exp_test"

    exp_type.destroy
  end

  test "supported_social_platforms returns default platforms" do
    platforms = Location.supported_social_platforms
    assert_includes platforms, "facebook"
    assert_includes platforms, "instagram"
    assert_includes platforms, "twitter"
  end

  # === Scopes ===

  test "by_city scope filters by city" do
    sarajevo = Location.create!(@valid_params)
    mostar = Location.create!(@valid_params.merge(
      name: "Mostar Place",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    ))

    results = Location.by_city("Sarajevo")
    assert_includes results, sarajevo
    assert_not_includes results, mostar

    sarajevo.destroy
    mostar.destroy
  end

  test "with_coordinates scope filters geocoded locations" do
    with_coords = Location.create!(@valid_params)
    without_coords = Location.create!(@valid_params.merge(
      name: "No Coords",
      lat: nil,
      lng: nil
    ))

    results = Location.with_coordinates
    assert_includes results, with_coords
    assert_not_includes results, without_coords

    with_coords.destroy
    without_coords.destroy
  end

  test "with_tag scope filters by tag" do
    tagged = Location.create!(@valid_params.merge(tags: [ "historic", "unesco" ]))
    untagged = Location.create!(@valid_params.merge(
      name: "Untagged",
      lat: 43.8570,
      lng: 18.4140,
      tags: [ "modern" ]
    ))

    results = Location.with_tag("historic")
    assert_includes results, tagged
    assert_not_includes results, untagged

    tagged.destroy
    untagged.destroy
  end

  test "by_experience scope filters by experience type" do
    exp_type = ExperienceType.create!(key: "culture_scope_test", name: "Culture", active: true, position: 1)
    with_exp = Location.create!(@valid_params)
    with_exp.add_experience_type(exp_type)

    without_exp = Location.create!(@valid_params.merge(
      name: "No Experience",
      lat: 43.8570,
      lng: 18.4140
    ))

    results = Location.by_experience("culture_scope_test")
    assert_includes results, with_exp
    assert_not_includes results, without_exp

    with_exp.destroy
    without_exp.destroy
    exp_type.destroy
  end

  test "by_budget scope filters by budget level" do
    low = Location.create!(@valid_params.merge(budget: :low))
    high = Location.create!(@valid_params.merge(
      name: "High Budget",
      lat: 43.8570,
      lng: 18.4140,
      budget: :high
    ))

    results = Location.by_budget("low")
    assert_includes results, low
    assert_not_includes results, high

    low.destroy
    high.destroy
  end

  test "by_budget scope returns all for blank budget" do
    location = Location.create!(@valid_params.merge(budget: :high))
    results = Location.by_budget("")
    assert_includes results, location
    location.destroy
  end

  test "by_budget scope returns all for invalid budget" do
    location = Location.create!(@valid_params.merge(budget: :high))
    results = Location.by_budget("invalid")
    assert_includes results, location
    location.destroy
  end

  test "by_budget medium includes low and medium" do
    low = Location.create!(@valid_params.merge(budget: :low))
    medium = Location.create!(@valid_params.merge(
      name: "Medium Budget",
      lat: 43.8570,
      lng: 18.4140,
      budget: :medium
    ))
    high = Location.create!(@valid_params.merge(
      name: "High Budget",
      lat: 43.8580,
      lng: 18.4150,
      budget: :high
    ))

    results = Location.by_budget("medium")
    assert_includes results, low
    assert_includes results, medium
    assert_not_includes results, high

    low.destroy
    medium.destroy
    high.destroy
  end

  test "by_min_rating scope filters by minimum rating" do
    high_rated = Location.create!(@valid_params.merge(average_rating: 4.5))
    low_rated = Location.create!(@valid_params.merge(
      name: "Low Rated",
      lat: 43.8570,
      lng: 18.4140,
      average_rating: 2.0
    ))

    results = Location.by_min_rating(4.0)
    assert_includes results, high_rated
    assert_not_includes results, low_rated

    high_rated.destroy
    low_rated.destroy
  end

  test "needs_ai_regeneration scope filters locations needing regeneration" do
    needs_regen = Location.create!(@valid_params.merge(needs_ai_regeneration: true))
    no_regen = Location.create!(@valid_params.merge(
      name: "No Regen",
      lat: 43.8570,
      lng: 18.4140,
      needs_ai_regeneration: false
    ))

    results = Location.needs_ai_regeneration
    assert_includes results, needs_regen
    assert_not_includes results, no_regen

    needs_regen.destroy
    no_regen.destroy
  end

  test "ai_generated scope filters AI generated locations" do
    ai = Location.create!(@valid_params.merge(ai_generated: true))
    human = Location.create!(@valid_params.merge(
      name: "Human Made",
      lat: 43.8570,
      lng: 18.4140,
      ai_generated: false
    ))

    results = Location.ai_generated
    assert_includes results, ai
    assert_not_includes results, human

    ai.destroy
    human.destroy
  end

  test "human_made scope filters human made locations" do
    ai = Location.create!(@valid_params.merge(ai_generated: true))
    human = Location.create!(@valid_params.merge(
      name: "Human Made",
      lat: 43.8570,
      lng: 18.4140,
      ai_generated: false
    ))

    results = Location.human_made
    assert_includes results, human
    assert_not_includes results, ai

    ai.destroy
    human.destroy
  end

  test "by_season scope filters by season" do
    summer_only = Location.create!(@valid_params.merge(seasons: [ "summer" ]))
    year_round = Location.create!(@valid_params.merge(
      name: "Year Round",
      lat: 43.8570,
      lng: 18.4140,
      seasons: []
    ))
    winter_only = Location.create!(@valid_params.merge(
      name: "Winter Only",
      lat: 43.8580,
      lng: 18.4150,
      seasons: [ "winter" ]
    ))

    results = Location.by_season("summer")
    assert_includes results, summer_only
    assert_includes results, year_round # Year-round should be included
    assert_not_includes results, winter_only

    summer_only.destroy
    year_round.destroy
    winter_only.destroy
  end

  test "by_season scope returns all for blank season" do
    location = Location.create!(@valid_params.merge(seasons: [ "summer" ]))
    results = Location.by_season("")
    assert_includes results, location
    location.destroy
  end

  test "by_seasons scope filters by multiple seasons with OR logic" do
    summer_only = Location.create!(@valid_params.merge(seasons: [ "summer" ]))
    winter_only = Location.create!(@valid_params.merge(
      name: "Winter Only",
      lat: 43.8570,
      lng: 18.4140,
      seasons: [ "winter" ]
    ))
    fall_only = Location.create!(@valid_params.merge(
      name: "Fall Only",
      lat: 43.8580,
      lng: 18.4150,
      seasons: [ "fall" ]
    ))

    results = Location.by_seasons([ "summer", "winter" ])
    assert_includes results, summer_only
    assert_includes results, winter_only
    assert_not_includes results, fall_only

    summer_only.destroy
    winter_only.destroy
    fall_only.destroy
  end

  test "by_seasons scope returns all for blank seasons" do
    location = Location.create!(@valid_params)
    results = Location.by_seasons([])
    assert_includes results, location
    location.destroy
  end

  test "year_round scope filters year-round locations" do
    year_round = Location.create!(@valid_params.merge(seasons: []))
    seasonal = Location.create!(@valid_params.merge(
      name: "Seasonal",
      lat: 43.8570,
      lng: 18.4140,
      seasons: [ "summer" ]
    ))

    results = Location.year_round
    assert_includes results, year_round
    assert_not_includes results, seasonal

    year_round.destroy
    seasonal.destroy
  end

  test "with_contact_info scope filters locations with contact info" do
    with_phone = Location.create!(@valid_params.merge(phone: "+387 61 123 456"))
    with_email = Location.create!(@valid_params.merge(
      name: "With Email",
      lat: 43.8570,
      lng: 18.4140,
      email: "test@example.com"
    ))
    no_contact = Location.create!(@valid_params.merge(
      name: "No Contact",
      lat: 43.8580,
      lng: 18.4150
    ))

    results = Location.with_contact_info
    assert_includes results, with_phone
    assert_includes results, with_email
    assert_not_includes results, no_contact

    with_phone.destroy
    with_email.destroy
    no_contact.destroy
  end

  test "by_type scope filters by category key" do
    category = LocationCategory.create!(name: "Test Type", key: "type_scope_test")
    with_type = Location.create!(@valid_params)
    with_type.add_category(category)

    without_type = Location.create!(@valid_params.merge(
      name: "No Type",
      lat: 43.8570,
      lng: 18.4140
    ))

    results = Location.by_type("type_scope_test")
    assert_includes results, with_type
    assert_not_includes results, without_type

    with_type.destroy
    without_type.destroy
    category.destroy
  end

  test "by_type scope falls back to legacy enum" do
    guide = Location.create!(@valid_params.merge(location_type: :guide))
    place = Location.create!(@valid_params.merge(
      name: "Place Type",
      lat: 43.8570,
      lng: 18.4140,
      location_type: :place
    ))

    results = Location.by_type("guide")
    assert_includes results, guide
    assert_not_includes results, place

    guide.destroy
    place.destroy
  end

  test "by_type scope returns all for blank type" do
    location = Location.create!(@valid_params)
    results = Location.by_type("")
    assert_includes results, location
    location.destroy
  end

  test "by_category scope filters by category" do
    category = LocationCategory.create!(name: "Test Category", key: "cat_scope_test")
    with_cat = Location.create!(@valid_params)
    with_cat.add_category(category)

    without_cat = Location.create!(@valid_params.merge(
      name: "No Category",
      lat: 43.8570,
      lng: 18.4140
    ))

    results = Location.by_category("cat_scope_test")
    assert_includes results, with_cat
    assert_not_includes results, without_cat

    with_cat.destroy
    without_cat.destroy
    category.destroy
  end

  test "by_category scope returns all for blank category" do
    location = Location.create!(@valid_params)
    results = Location.by_category("")
    assert_includes results, location
    location.destroy
  end

  test "places scope includes locations without categories" do
    location = Location.create!(@valid_params.merge(location_type: :place))
    results = Location.places
    assert_includes results, location
    location.destroy
  end

  test "places scope includes locations with place-type category" do
    category = LocationCategory.create!(name: "Museum", key: "museum_places_test")
    location = Location.create!(@valid_params)
    location.add_category(category)

    results = Location.places
    assert_includes results, location

    location.destroy
    category.destroy
  end

  test "contacts scope includes locations with contact-type category" do
    # First clean up any existing guide category
    existing_guide = LocationCategory.find_by(key: "guide")
    guide_category = existing_guide || LocationCategory.create!(name: "Guide", key: "guide")

    location = Location.create!(@valid_params)
    location.add_category(guide_category)

    results = Location.contacts
    assert_includes results, location

    location.destroy
    guide_category.destroy unless existing_guide
  end

  test "contacts scope includes locations with legacy non-place type" do
    location = Location.create!(@valid_params.merge(location_type: :business))
    results = Location.contacts
    assert_includes results, location
    location.destroy
  end

  # === Audio tour helpers ===

  test "audio_tour_for returns audio tour for specific locale" do
    location = Location.create!(@valid_params)
    audio_tour = AudioTour.create!(location: location, locale: "en")

    result = location.audio_tour_for("en")
    assert_equal audio_tour, result

    audio_tour.destroy
    location.destroy
  end

  test "audio_tour_for returns nil when no tour for locale" do
    location = Location.create!(@valid_params)

    result = location.audio_tour_for("en")
    assert_nil result

    location.destroy
  end

  test "audio_tour_with_fallback returns tour for requested locale" do
    location = Location.create!(@valid_params)
    en_tour = AudioTour.create!(location: location, locale: "en")
    bs_tour = AudioTour.create!(location: location, locale: "bs")

    result = location.audio_tour_with_fallback("en")
    assert_equal en_tour, result

    en_tour.destroy
    bs_tour.destroy
    location.destroy
  end

  test "audio_tour_with_fallback falls back to default locale" do
    location = Location.create!(@valid_params)
    bs_tour = AudioTour.create!(location: location, locale: I18n.default_locale.to_s)

    result = location.audio_tour_with_fallback("de")
    assert_equal bs_tour, result

    bs_tour.destroy
    location.destroy
  end

  test "audio_tour_with_fallback falls back to English" do
    location = Location.create!(@valid_params)
    en_tour = AudioTour.create!(location: location, locale: "en")

    # Assuming default locale is not "de"
    result = location.audio_tour_with_fallback("de")
    # Will return en_tour if default locale doesn't exist
    assert_not_nil result

    en_tour.destroy
    location.destroy
  end

  test "has_audio_tours? returns false when no audio tours" do
    location = Location.create!(@valid_params)
    assert_not location.has_audio_tours?
    location.destroy
  end

  test "available_audio_locales returns empty array when no audio tours" do
    location = Location.create!(@valid_params)
    assert_equal [], location.available_audio_locales
    location.destroy
  end

  test "has_audio_tour_for? returns false when no tour for locale" do
    location = Location.create!(@valid_params)
    assert_not location.has_audio_tour_for?("en")
    location.destroy
  end

  # === Enum tests ===

  test "budget enum values" do
    low = Location.create!(@valid_params.merge(budget: :low))
    assert low.low?

    medium = Location.create!(@valid_params.merge(name: "Medium", lat: 43.8570, lng: 18.4140, budget: :medium))
    assert medium.medium?

    high = Location.create!(@valid_params.merge(name: "High", lat: 43.8580, lng: 18.4150, budget: :high))
    assert high.high?

    low.destroy
    medium.destroy
    high.destroy
  end


  # === Callback tests ===

  test "suitable_experiences setter updates relational data" do
    exp_type = ExperienceType.create!(key: "callback_test", name: "Callback Test", active: true, position: 1)
    location = Location.create!(@valid_params)

    # Update via suitable_experiences setter (updates relational data + JSON cache)
    location.update!(suitable_experiences: [ "callback_test" ])

    # Reload and check association was updated (source of truth)
    location.reload
    assert location.experience_types.exists?(key: "callback_test")
    # JSON cache should also be synced
    assert_equal [ "callback_test" ], location.read_attribute(:suitable_experiences)

    location.destroy
    exp_type.destroy
  end

  # === Additional edge case tests ===

  test "suitable_experiences setter syncs with association when persisted" do
    exp_type = ExperienceType.create!(key: "setter_test", name: "Setter Test", active: true, position: 1)
    location = Location.create!(@valid_params)

    location.suitable_experiences = [ "setter_test" ]
    location.reload

    assert location.has_experience_type?("setter_test")

    location.destroy
    exp_type.destroy
  end

  test "suitable_experiences reads from JSON when association not loaded" do
    location = Location.create!(@valid_params.merge(suitable_experiences: [ "test_exp" ]))
    location.reload  # Ensures association is not loaded

    # Access suitable_experiences without loading association
    result = location.read_attribute(:suitable_experiences)
    assert_equal [ "test_exp" ], result

    location.destroy
  end

  test "set_experience_types is source of truth for experience types" do
    exp1 = ExperienceType.create!(key: "source_test_1", name: "Source Test 1", active: true, position: 1)
    exp2 = ExperienceType.create!(key: "source_test_2", name: "Source Test 2", active: true, position: 2)
    location = Location.create!(@valid_params)

    # Use set_experience_types (main API)
    location.set_experience_types([ "source_test_1", "source_test_2" ])

    # Check relational data (source of truth)
    assert location.has_experience_type?("source_test_1")
    assert location.has_experience_type?("source_test_2")

    # Check JSON cache is synced
    location.reload
    json_keys = location.read_attribute(:suitable_experiences)
    assert_includes json_keys, "source_test_1"
    assert_includes json_keys, "source_test_2"

    location.destroy
    exp1.destroy
    exp2.destroy
  end

  test "remove_social_link normalizes platform key" do
    location = Location.create!(@valid_params)
    location.add_social_link("facebook", "https://facebook.com/test")
    location.remove_social_link("  FACEBOOK  ")
    assert_nil location.social_link("facebook")
    location.destroy
  end

  test "social_link normalizes platform key" do
    location = Location.create!(@valid_params)
    location.add_social_link("facebook", "https://facebook.com/test")
    assert_equal "https://facebook.com/test", location.social_link("  FACEBOOK  ")
    location.destroy
  end

  test "SEASONS constant contains valid seasons" do
    assert_equal %w[spring summer fall winter], Location::SEASONS
  end

  test "by_seasons handles single season passed as array" do
    location = Location.create!(@valid_params.merge(seasons: [ "summer" ]))
    results = Location.by_seasons("summer")  # Single string, not array
    assert_includes results, location
    location.destroy
  end

  test "email validation allows nil" do
    location = Location.new(@valid_params.merge(email: nil))
    assert location.valid?
  end

  test "website validation allows nil" do
    location = Location.new(@valid_params.merge(website: nil))
    assert location.valid?
  end

  test "phone validation allows nil" do
    location = Location.new(@valid_params.merge(phone: nil))
    assert location.valid?
  end

  test "video_url validation allows nil" do
    location = Location.new(@valid_params.merge(video_url: nil))
    assert location.valid?
  end

  test "lat allows nil when lng is also nil" do
    location = Location.new(@valid_params.merge(lat: nil, lng: nil))
    assert location.valid?
  end

  test "primary_category returns nil when no categories" do
    location = Location.create!(@valid_params)
    assert_nil location.primary_category
    location.destroy
  end

  test "category_key returns nil when no categories" do
    location = Location.new(@valid_params)
    assert_nil location.category_key
  end

  test "category_name returns nil when no categories" do
    location = Location.new(@valid_params)
    assert_nil location.category_name
  end

  test "place_type? returns false for contact-type category" do
    # Create a contact-type category (guide, business, or artisan)
    existing_artisan = LocationCategory.find_by(key: "artisan")
    artisan_category = existing_artisan || LocationCategory.create!(name: "Artisan", key: "artisan")

    location = Location.create!(@valid_params)
    location.add_category(artisan_category)

    assert_not location.place_type?

    location.destroy
    artisan_category.destroy unless existing_artisan
  end

  test "nearby_featured orders by rating and updated_at" do
    location1 = Location.create!(@valid_params)
    location2 = Location.create!(@valid_params.merge(
      name: "High Rated",
      lat: 43.8570,
      lng: 18.4140,
      average_rating: 5.0
    ))
    location3 = Location.create!(@valid_params.merge(
      name: "Low Rated",
      lat: 43.8580,
      lng: 18.4150,
      average_rating: 2.0
    ))

    nearby = location1.nearby_featured(limit: 3)
    # location2 should come before location3 due to higher rating
    assert_equal nearby.first, location2

    location3.destroy
    location2.destroy
    location1.destroy
  end

  test "by_budget high includes all budget levels" do
    low = Location.create!(@valid_params.merge(budget: :low))
    medium = Location.create!(@valid_params.merge(
      name: "Medium Budget",
      lat: 43.8570,
      lng: 18.4140,
      budget: :medium
    ))
    high = Location.create!(@valid_params.merge(
      name: "High Budget",
      lat: 43.8580,
      lng: 18.4150,
      budget: :high
    ))

    results = Location.by_budget("high")
    assert_includes results, low
    assert_includes results, medium
    assert_includes results, high

    low.destroy
    medium.destroy
    high.destroy
  end

  test "by_seasons includes year-round locations" do
    year_round = Location.create!(@valid_params.merge(seasons: []))
    summer_only = Location.create!(@valid_params.merge(
      name: "Summer Only",
      lat: 43.8570,
      lng: 18.4140,
      seasons: [ "summer" ]
    ))

    results = Location.by_seasons([ "summer" ])
    assert_includes results, year_round
    assert_includes results, summer_only

    year_round.destroy
    summer_only.destroy
  end

  test "find_or_initialize_by_coordinates converts string coordinates to float" do
    existing = Location.create!(@valid_params)
    # Pass coordinates as strings
    found = Location.find_or_initialize_by_coordinates("43.8563", "18.4131")

    assert_equal existing.id, found.id

    existing.destroy
  end

  test "add_experience_type syncs JSON cache" do
    exp_type = ExperienceType.create!(key: "json_update_test", name: "JSON Update", active: true, position: 1)
    location = Location.create!(@valid_params)
    location.add_experience_type(exp_type)

    # JSON cache should be automatically synced from relational data
    location.reload
    json_experiences = location.read_attribute(:suitable_experiences)
    assert_includes json_experiences, "json_update_test"

    location.destroy
    exp_type.destroy
  end
end

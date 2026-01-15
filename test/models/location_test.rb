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
    assert_equal [43.8563, 18.4131], location.coordinates
  end

  test "coordinates returns nil when not geocoded" do
    location = Location.new(@valid_params.merge(lat: nil, lng: nil))
    assert_nil location.coordinates
  end

  # === Tag helpers ===

  test "tags returns empty array by default" do
    location = Location.new(@valid_params)
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
    location = Location.new(@valid_params.merge(seasons: ["summer"]))
    assert_not location.year_round?
  end

  test "available_in_season? returns true for year-round locations" do
    location = Location.new(@valid_params)
    assert location.available_in_season?("summer")
    assert location.available_in_season?("winter")
  end

  test "available_in_season? returns true when season matches" do
    location = Location.new(@valid_params.merge(seasons: ["summer"]))
    assert location.available_in_season?("summer")
    assert_not location.available_in_season?("winter")
  end

  test "add_season adds valid season" do
    location = Location.create!(@valid_params)
    location.add_season("summer")
    assert_includes location.seasons, "summer"
    location.destroy
  end

  test "add_season ignores invalid seasons" do
    location = Location.create!(@valid_params)
    location.add_season("invalid_season")
    assert_not_includes location.seasons, "invalid_season"
    location.destroy
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

  test "remove_social_link removes platform" do
    location = Location.create!(@valid_params)
    location.add_social_link("facebook", "https://facebook.com/test")
    location.remove_social_link("facebook")
    assert_nil location.social_link("facebook")
    location.destroy
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

  test "has_category? checks for category presence" do
    category = LocationCategory.create!(name: "Test", key: "test_category")
    location = Location.create!(@valid_params)

    assert_not location.has_category?("test_category")

    location.add_category(category)
    assert location.has_category?("test_category")

    location.destroy
    category.destroy
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

  test "find_by_coordinates_fuzzy finds locations within tolerance" do
    location = Location.create!(@valid_params)

    # Slightly different coordinates
    found = Location.find_by_coordinates_fuzzy(43.85631, 18.41311)
    assert_equal location, found

    location.destroy
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
end

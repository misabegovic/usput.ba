# frozen_string_literal: true

require "test_helper"

class BrowseTest < ActiveSupport::TestCase
  # Helper method to create a location with unique coordinates
  def create_test_location(name:, city: "Sarajevo", lat: nil, lng: nil, **options)
    lat ||= 43.8 + rand * 0.1
    lng ||= 18.4 + rand * 0.1
    Location.create!(
      name: name,
      city: city,
      lat: lat,
      lng: lng,
      location_type: :place,
      **options
    )
  end

  # === Validation tests ===

  test "validates presence of title" do
    browse = Browse.new(browsable_type: "Location", browsable_id: 1)
    assert_not browse.valid?
    assert_includes browse.errors[:title], "can't be blank"
  end

  test "validates browsable_type inclusion" do
    # Test that only Location, Experience, and Plan are valid browsable types
    # We can verify this by checking the validation definition directly
    validation = Browse.validators_on(:browsable_type).find { |v| v.is_a?(ActiveModel::Validations::InclusionValidator) }
    assert_not_nil validation, "Should have inclusion validation on browsable_type"
    assert_equal %w[Location Experience Plan], validation.options[:in]
  end

  test "validates uniqueness of browsable_id scoped to browsable_type" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    # Try to create a duplicate browse record
    duplicate = Browse.new(
      title: "Duplicate",
      browsable_type: "Location",
      browsable_id: location.id
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:browsable_id], "has already been taken"

    location.destroy
  end

  # === Type filter scope tests ===

  test "locations scope returns only Location type" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    experience = Experience.create!(title: "Test Experience")
    Browse.sync_record(experience)

    results = Browse.locations
    assert results.all? { |b| b.browsable_type == "Location" }
    assert_includes results.pluck(:browsable_id), location.id

    location.destroy
    experience.destroy
  end

  test "experiences scope returns only Experience type" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    experience = Experience.create!(title: "Test Experience")
    Browse.sync_record(experience)

    results = Browse.experiences
    assert results.all? { |b| b.browsable_type == "Experience" }
    assert_includes results.pluck(:browsable_id), experience.id

    location.destroy
    experience.destroy
  end

  test "plans scope returns only Plan type" do
    plan = Plan.create!(title: "Test Plan", visibility: :public_plan, city_name: "Sarajevo")
    Browse.sync_record(plan)

    experience = Experience.create!(title: "Test Experience")
    Browse.sync_record(experience)

    results = Browse.plans
    assert results.all? { |b| b.browsable_type == "Plan" }
    assert_includes results.pluck(:browsable_id), plan.id

    plan.destroy
    experience.destroy
  end

  # === by_city_name scope tests ===

  test "by_city_name filters locations by city" do
    # Create a location in Sarajevo
    location = Location.create!(
      name: "Test Location Sarajevo",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )
    Browse.sync_record(location)

    # Create a location in Mostar
    location_mostar = Location.create!(
      name: "Test Location Mostar",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )
    Browse.sync_record(location_mostar)

    # Filter by Sarajevo should find only Sarajevo location
    sarajevo_results = Browse.by_city_name("Sarajevo").locations
    assert_includes sarajevo_results.pluck(:browsable_id), location.id
    assert_not_includes sarajevo_results.pluck(:browsable_id), location_mostar.id

    # Cleanup
    location.destroy
    location_mostar.destroy
  end

  test "by_city_name finds experiences with multiple locations when filtering by any city" do
    # Create locations in different cities
    location_sarajevo = Location.create!(
      name: "Sarajevo Stop",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    location_mostar = Location.create!(
      name: "Mostar Stop",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )

    location_banja_luka = Location.create!(
      name: "Banja Luka Stop",
      city: "Banja Luka",
      lat: 44.7758,
      lng: 17.1858,
      location_type: :place
    )

    # Create an experience with multiple locations (Sarajevo and Mostar)
    multi_city_experience = Experience.create!(
      title: "Bosnia Tour - Sarajevo to Mostar"
    )
    multi_city_experience.add_location(location_sarajevo, position: 1)
    multi_city_experience.add_location(location_mostar, position: 2)
    Browse.sync_record(multi_city_experience)

    # Create a single-city experience (only Banja Luka)
    single_city_experience = Experience.create!(
      title: "Banja Luka City Tour"
    )
    single_city_experience.add_location(location_banja_luka, position: 1)
    Browse.sync_record(single_city_experience)

    # Filter by Sarajevo should find multi_city_experience (first location is Sarajevo)
    sarajevo_experiences = Browse.by_city_name("Sarajevo").experiences
    assert_includes sarajevo_experiences.pluck(:browsable_id), multi_city_experience.id,
      "Experience with first location in Sarajevo should be found"
    assert_not_includes sarajevo_experiences.pluck(:browsable_id), single_city_experience.id

    # Filter by Mostar should also find multi_city_experience (second location is Mostar)
    mostar_experiences = Browse.by_city_name("Mostar").experiences
    assert_includes mostar_experiences.pluck(:browsable_id), multi_city_experience.id,
      "Experience with second location in Mostar should be found when filtering by Mostar"
    assert_not_includes mostar_experiences.pluck(:browsable_id), single_city_experience.id

    # Filter by Banja Luka should find only single_city_experience
    banja_luka_experiences = Browse.by_city_name("Banja Luka").experiences
    assert_includes banja_luka_experiences.pluck(:browsable_id), single_city_experience.id
    assert_not_includes banja_luka_experiences.pluck(:browsable_id), multi_city_experience.id

    # Cleanup
    multi_city_experience.destroy
    single_city_experience.destroy
    location_sarajevo.destroy
    location_mostar.destroy
    location_banja_luka.destroy
  end

  test "by_city_name returns empty when no experiences in city" do
    results = Browse.by_city_name("NonExistentCity").experiences
    assert_empty results
  end

  test "by_city_name returns all records when city is blank" do
    # Should return all records when city_name is blank
    all_count = Browse.all.count
    filtered_count = Browse.by_city_name("").count
    assert_equal all_count, filtered_count

    filtered_count_nil = Browse.by_city_name(nil).count
    assert_equal all_count, filtered_count_nil
  end

  # === ai_generated scope tests ===

  test "ai_generated scope filters to AI generated content" do
    # Create an AI-generated location
    ai_location = Location.create!(
      name: "AI Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      ai_generated: true
    )
    Browse.sync_record(ai_location)

    # Create a human-made location
    human_location = Location.create!(
      name: "Human Location",
      city: "Sarajevo",
      lat: 43.8564,
      lng: 18.4132,
      location_type: :place,
      ai_generated: false
    )
    Browse.sync_record(human_location)

    # Filter by AI generated
    ai_results = Browse.ai_generated.locations
    assert_includes ai_results.pluck(:browsable_id), ai_location.id
    assert_not_includes ai_results.pluck(:browsable_id), human_location.id

    # Filter by human made
    human_results = Browse.human_made.locations
    assert_includes human_results.pluck(:browsable_id), human_location.id
    assert_not_includes human_results.pluck(:browsable_id), ai_location.id

    # Cleanup
    ai_location.destroy
    human_location.destroy
  end

  test "by_origin scope filters by origin type" do
    ai_location = Location.create!(
      name: "AI Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      ai_generated: true
    )
    Browse.sync_record(ai_location)

    human_location = Location.create!(
      name: "Human Location",
      city: "Sarajevo",
      lat: 43.8564,
      lng: 18.4132,
      location_type: :place,
      ai_generated: false
    )
    Browse.sync_record(human_location)

    # Test by_origin with "ai"
    ai_results = Browse.by_origin("ai").locations
    assert_includes ai_results.pluck(:browsable_id), ai_location.id
    assert_not_includes ai_results.pluck(:browsable_id), human_location.id

    # Test by_origin with "human"
    human_results = Browse.by_origin("human").locations
    assert_includes human_results.pluck(:browsable_id), human_location.id
    assert_not_includes human_results.pluck(:browsable_id), ai_location.id

    # Test by_origin with blank returns all
    all_results = Browse.by_origin("").locations
    assert_includes all_results.pluck(:browsable_id), ai_location.id
    assert_includes all_results.pluck(:browsable_id), human_location.id

    # Cleanup
    ai_location.destroy
    human_location.destroy
  end

  test "BrowseAdapter includes ai_generated attribute for locations" do
    location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      ai_generated: false
    )

    attrs = BrowseAdapter.attributes_for(location)
    assert_not_nil attrs[:ai_generated]
    assert_equal false, attrs[:ai_generated]

    location.destroy
  end

  test "BrowseAdapter includes seasons for locations" do
    location = Location.create!(
      name: "Summer Beach",
      city: "Neum",
      lat: 42.9247,
      lng: 17.6141,
      location_type: :place,
      seasons: %w[summer]
    )

    attrs = BrowseAdapter.attributes_for(location)
    assert_equal %w[summer], attrs[:seasons]

    location.destroy
  end

  # === Search scope tests ===

  test "search scope returns all records when query is blank" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.search("").count
    assert_equal all_count, Browse.search(nil).count

    location.destroy
  end

  test "search_fuzzy scope returns all records when query is blank" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.search_fuzzy("").count
    assert_equal all_count, Browse.search_fuzzy(nil).count

    location.destroy
  end

  test "search_fuzzy scope finds locations by partial title match" do
    location = create_test_location(name: "Beautiful Mountain View")
    Browse.sync_record(location)

    results = Browse.search_fuzzy("mountain")
    assert_includes results.pluck(:browsable_id), location.id

    location.destroy
  end

  test "search_fuzzy scope is case insensitive" do
    location = create_test_location(name: "Beautiful Mountain View")
    Browse.sync_record(location)

    results = Browse.search_fuzzy("MOUNTAIN")
    assert_includes results.pluck(:browsable_id), location.id

    location.destroy
  end

  test "smart_search returns all records when query is blank" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.smart_search("").count
    assert_equal all_count, Browse.smart_search(nil).count

    location.destroy
  end

  # === Filter scope tests ===

  test "by_min_rating filters locations by minimum rating" do
    high_rated = create_test_location(name: "High Rated", average_rating: 4.5)
    Browse.sync_record(high_rated)

    low_rated = create_test_location(name: "Low Rated", average_rating: 2.0)
    Browse.sync_record(low_rated)

    results = Browse.by_min_rating(4.0).locations
    assert_includes results.pluck(:browsable_id), high_rated.id
    assert_not_includes results.pluck(:browsable_id), low_rated.id

    high_rated.destroy
    low_rated.destroy
  end

  test "by_min_rating returns all records when min_rating is blank" do
    location = create_test_location(name: "Test Location", average_rating: 3.0)
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.by_min_rating("").count
    assert_equal all_count, Browse.by_min_rating(nil).count

    location.destroy
  end

  test "by_subtype filters by browsable_subtype" do
    location = create_test_location(name: "Restaurant Test")
    Browse.sync_record(location)
    # Update the browse record with a subtype
    Browse.find_by(browsable: location).update!(browsable_subtype: "restaurant")

    other_location = create_test_location(name: "Museum Test")
    Browse.sync_record(other_location)
    Browse.find_by(browsable: other_location).update!(browsable_subtype: "museum")

    results = Browse.by_subtype("restaurant")
    assert_includes results.pluck(:browsable_id), location.id
    assert_not_includes results.pluck(:browsable_id), other_location.id

    location.destroy
    other_location.destroy
  end

  test "by_subtype returns all records when subtype is blank" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.by_subtype("").count
    assert_equal all_count, Browse.by_subtype(nil).count

    location.destroy
  end

  test "by_budget filters locations by budget level" do
    low_budget = create_test_location(name: "Cheap Place", budget: :low)
    Browse.sync_record(low_budget)

    high_budget = create_test_location(name: "Expensive Place", budget: :high)
    Browse.sync_record(high_budget)

    # by_budget is cumulative: low returns low, medium returns low+medium, high returns all
    results = Browse.by_budget("low").locations
    assert_includes results.pluck(:browsable_id), low_budget.id
    # High budget should NOT be included in "low" filter
    assert_not_includes results.pluck(:browsable_id), high_budget.id

    low_budget.destroy
    high_budget.destroy
  end

  test "by_budget returns all records when budget is blank or invalid" do
    location = create_test_location(name: "Test Location", budget: :medium)
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.by_budget("").count
    assert_equal all_count, Browse.by_budget(nil).count
    assert_equal all_count, Browse.by_budget("invalid").count

    location.destroy
  end

  test "by_category_key filters by category_keys jsonb array" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)
    Browse.find_by(browsable: location).update!(category_keys: [ "cafe", "restaurant" ])

    other_location = create_test_location(name: "Other Location")
    Browse.sync_record(other_location)
    Browse.find_by(browsable: other_location).update!(category_keys: [ "museum" ])

    results = Browse.by_category_key("cafe")
    assert_includes results.pluck(:browsable_id), location.id
    assert_not_includes results.pluck(:browsable_id), other_location.id

    location.destroy
    other_location.destroy
  end

  test "by_category_key returns all records when category_key is blank" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.by_category_key("").count
    assert_equal all_count, Browse.by_category_key(nil).count

    location.destroy
  end

  # === Season scope tests ===

  test "by_season filters by season in jsonb array" do
    summer_location = create_test_location(name: "Summer Beach", seasons: %w[summer])
    Browse.sync_record(summer_location)

    winter_location = create_test_location(name: "Ski Resort", seasons: %w[winter])
    Browse.sync_record(winter_location)

    results = Browse.by_season("summer").locations
    assert_includes results.pluck(:browsable_id), summer_location.id
    assert_not_includes results.pluck(:browsable_id), winter_location.id

    summer_location.destroy
    winter_location.destroy
  end

  test "by_season includes year-round locations (empty seasons array)" do
    year_round_location = create_test_location(name: "Year Round Place", seasons: [])
    Browse.sync_record(year_round_location)

    summer_only = create_test_location(name: "Summer Only", seasons: %w[summer])
    Browse.sync_record(summer_only)

    # Year-round locations should be included in any season filter
    results = Browse.by_season("winter").locations
    assert_includes results.pluck(:browsable_id), year_round_location.id
    assert_not_includes results.pluck(:browsable_id), summer_only.id

    year_round_location.destroy
    summer_only.destroy
  end

  test "by_season returns all records when season is blank" do
    location = create_test_location(name: "Test Location", seasons: %w[summer])
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.by_season("").count
    assert_equal all_count, Browse.by_season(nil).count

    location.destroy
  end

  test "by_seasons filters by multiple seasons with OR logic" do
    spring_location = create_test_location(name: "Spring Garden", seasons: %w[spring])
    Browse.sync_record(spring_location)

    summer_location = create_test_location(name: "Beach", seasons: %w[summer])
    Browse.sync_record(summer_location)

    fall_location = create_test_location(name: "Fall Foliage", seasons: %w[fall])
    Browse.sync_record(fall_location)

    # Filter by spring or summer should return both spring and summer locations
    results = Browse.by_seasons(%w[spring summer]).locations
    assert_includes results.pluck(:browsable_id), spring_location.id
    assert_includes results.pluck(:browsable_id), summer_location.id
    assert_not_includes results.pluck(:browsable_id), fall_location.id

    spring_location.destroy
    summer_location.destroy
    fall_location.destroy
  end

  test "by_seasons returns all records when seasons is blank" do
    location = create_test_location(name: "Test Location", seasons: %w[summer])
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.by_seasons("").count
    assert_equal all_count, Browse.by_seasons(nil).count
    assert_equal all_count, Browse.by_seasons([]).count

    location.destroy
  end

  # === Nearby scope tests ===

  test "nearby scope returns all records when coordinates are blank" do
    location = create_test_location(name: "Test Location", lat: 43.8563, lng: 18.4131)
    Browse.sync_record(location)

    all_count = Browse.count
    assert_equal all_count, Browse.nearby(nil, nil).count
    assert_equal all_count, Browse.nearby("", "").count

    location.destroy
  end

  test "nearby scope returns none when no locations in radius" do
    # Create a location in Sarajevo
    sarajevo_location = create_test_location(name: "Sarajevo Place", lat: 43.8563, lng: 18.4131)
    Browse.sync_record(sarajevo_location)

    # Search near a distant location (e.g., New York - very far from Sarajevo)
    results = Browse.nearby(40.7128, -74.0060, radius_km: 10)
    assert_empty results

    sarajevo_location.destroy
  end

  test "nearby scope finds locations within radius" do
    # Create a location in central Sarajevo
    central = create_test_location(name: "Central Sarajevo", lat: 43.8563, lng: 18.4131)
    Browse.sync_record(central)

    # Create a location nearby (about 5km away)
    nearby = create_test_location(name: "Nearby Place", lat: 43.8700, lng: 18.4200)
    Browse.sync_record(nearby)

    # Create a distant location (about 200km away - Dubrovnik)
    distant = create_test_location(name: "Distant Place", city: "Dubrovnik", lat: 42.6507, lng: 18.0944)
    Browse.sync_record(distant)

    # Search within 25km radius should find central and nearby
    results = Browse.nearby(43.8563, 18.4131, radius_km: 25)
    assert_includes results.pluck(:browsable_id), central.id
    assert_includes results.pluck(:browsable_id), nearby.id
    assert_not_includes results.pluck(:browsable_id), distant.id

    central.destroy
    nearby.destroy
    distant.destroy
  end

  # === Sorting scope tests ===

  test "by_relevance orders by average_rating and reviews_count descending" do
    low_rated = create_test_location(name: "Low Rated", average_rating: 2.0, reviews_count: 10)
    Browse.sync_record(low_rated)

    high_rated = create_test_location(name: "High Rated", average_rating: 4.5, reviews_count: 5)
    Browse.sync_record(high_rated)

    results = Browse.locations.by_relevance.pluck(:browsable_id)
    # High rated should come first
    assert_equal high_rated.id, results.first

    low_rated.destroy
    high_rated.destroy
  end

  test "by_rating orders by average_rating descending" do
    low_rated = create_test_location(name: "Low Rated", average_rating: 2.0)
    Browse.sync_record(low_rated)

    high_rated = create_test_location(name: "High Rated", average_rating: 4.5)
    Browse.sync_record(high_rated)

    results = Browse.locations.by_rating.pluck(:browsable_id)
    assert_equal high_rated.id, results.first

    low_rated.destroy
    high_rated.destroy
  end

  test "by_newest orders by created_at descending" do
    older = create_test_location(name: "Older Location")
    Browse.sync_record(older)

    sleep 0.1 # Ensure different timestamps

    newer = create_test_location(name: "Newer Location")
    Browse.sync_record(newer)

    results = Browse.locations.by_newest.pluck(:browsable_id)
    assert_equal newer.id, results.first

    older.destroy
    newer.destroy
  end

  test "by_name orders by title ascending" do
    zebra = create_test_location(name: "Zebra Place")
    Browse.sync_record(zebra)

    apple = create_test_location(name: "Apple Place")
    Browse.sync_record(apple)

    results = Browse.locations.by_name
    titles = results.pluck(:title)
    assert_equal titles, titles.sort

    zebra.destroy
    apple.destroy
  end

  # === Instance method tests ===

  test "original_record returns the associated browsable record" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    browse = Browse.find_by(browsable: location)
    assert_equal location, browse.original_record

    location.destroy
  end

  test "location? returns true for Location type" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    browse = Browse.find_by(browsable: location)
    assert browse.location?
    assert_not browse.experience?
    assert_not browse.plan?

    location.destroy
  end

  test "experience? returns true for Experience type" do
    experience = Experience.create!(title: "Test Experience")
    Browse.sync_record(experience)

    browse = Browse.find_by(browsable: experience)
    assert browse.experience?
    assert_not browse.location?
    assert_not browse.plan?

    experience.destroy
  end

  test "plan? returns true for Plan type" do
    plan = Plan.create!(title: "Test Plan", visibility: :public_plan, city_name: "Sarajevo")
    Browse.sync_record(plan)

    browse = Browse.find_by(browsable: plan)
    assert browse.plan?
    assert_not browse.location?
    assert_not browse.experience?

    plan.destroy
  end

  # === Class method tests ===

  test "sync_record creates browse record for location with place type" do
    location = create_test_location(name: "Test Location")
    Browse.remove_record(location) # Ensure clean state

    Browse.sync_record(location)

    browse = Browse.find_by(browsable: location)
    assert_not_nil browse
    assert_equal location.name, browse.title

    location.destroy
  end

  test "sync_record does not create browse record for contact type location" do
    location = Location.create!(
      name: "Test Guide",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :guide
    )

    Browse.sync_record(location)

    browse = Browse.find_by(browsable: location)
    assert_nil browse

    location.destroy
  end

  test "sync_record creates browse record for experience" do
    experience = Experience.create!(title: "Test Experience")

    Browse.sync_record(experience)

    browse = Browse.find_by(browsable: experience)
    assert_not_nil browse
    assert_equal experience.title, browse.title

    experience.destroy
  end

  test "sync_record creates browse record for public plan" do
    plan = Plan.create!(title: "Public Plan", visibility: :public_plan, city_name: "Sarajevo")

    Browse.sync_record(plan)

    browse = Browse.find_by(browsable: plan)
    assert_not_nil browse
    assert_equal plan.title, browse.title

    plan.destroy
  end

  test "sync_record does not create browse record for private plan" do
    plan = Plan.create!(title: "Private Plan", visibility: :private_plan, city_name: "Sarajevo")

    Browse.sync_record(plan)

    browse = Browse.find_by(browsable: plan)
    assert_nil browse

    plan.destroy
  end

  test "sync_record updates existing browse record" do
    location = create_test_location(name: "Original Name")
    Browse.sync_record(location)

    location.update!(name: "Updated Name")
    Browse.sync_record(location)

    browse = Browse.find_by(browsable: location)
    assert_equal "Updated Name", browse.title

    location.destroy
  end

  test "remove_record destroys browse record for given record" do
    location = create_test_location(name: "Test Location")
    Browse.sync_record(location)

    assert_not_nil Browse.find_by(browsable: location)

    Browse.remove_record(location)

    assert_nil Browse.find_by(browsable: location)

    location.destroy
  end

  test "syncable? returns true for place type location" do
    location = create_test_location(name: "Test Place")
    assert Browse.syncable?(location)
    location.destroy
  end

  test "syncable? returns false for contact type location" do
    location = Location.create!(
      name: "Test Guide",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :guide
    )
    assert_not Browse.syncable?(location)
    location.destroy
  end

  test "syncable? returns true for experience" do
    experience = Experience.create!(title: "Test Experience")
    assert Browse.syncable?(experience)
    experience.destroy
  end

  test "syncable? returns true for public plan" do
    plan = Plan.create!(title: "Public Plan", visibility: :public_plan, city_name: "Sarajevo")
    assert Browse.syncable?(plan)
    plan.destroy
  end

  test "syncable? returns false for private plan" do
    plan = Plan.create!(title: "Private Plan", visibility: :private_plan, city_name: "Sarajevo")
    assert_not Browse.syncable?(plan)
    plan.destroy
  end

  test "syncable? returns false for unsupported record types" do
    # Use a simple object that is not Location, Experience, or Plan
    # Using a struct to simulate an unsupported record type
    unsupported_record = Struct.new(:id).new(1)
    assert_not Browse.syncable?(unsupported_record)
  end

  test "rebuild_all! rebuilds browse table from scratch" do
    # Create test data
    location = create_test_location(name: "Test Location")
    experience = Experience.create!(title: "Test Experience")
    public_plan = Plan.create!(title: "Public Plan", visibility: :public_plan, city_name: "Sarajevo")
    private_plan = Plan.create!(title: "Private Plan", visibility: :private_plan, city_name: "Sarajevo")

    # Clear all browse records
    Browse.delete_all

    # Rebuild
    Browse.rebuild_all!

    # Verify records were created
    assert_not_nil Browse.find_by(browsable: location)
    assert_not_nil Browse.find_by(browsable: experience)
    assert_not_nil Browse.find_by(browsable: public_plan)
    assert_nil Browse.find_by(browsable: private_plan)

    location.destroy
    experience.destroy
    public_plan.destroy
    private_plan.destroy
  end

  # === by_origin scope additional tests ===

  test "by_origin with ai_generated variant" do
    ai_location = create_test_location(name: "AI Generated", ai_generated: true)
    Browse.sync_record(ai_location)

    results = Browse.by_origin("ai_generated").locations
    assert_includes results.pluck(:browsable_id), ai_location.id

    ai_location.destroy
  end

  test "by_origin with human_made variant" do
    human_location = create_test_location(name: "Human Made", ai_generated: false)
    Browse.sync_record(human_location)

    results = Browse.by_origin("human_made").locations
    assert_includes results.pluck(:browsable_id), human_location.id

    human_location.destroy
  end

  # === by_city_name tests for plans ===

  test "by_city_name filters plans by city_name" do
    sarajevo_plan = Plan.create!(title: "Sarajevo Plan", visibility: :public_plan, city_name: "Sarajevo")
    Browse.sync_record(sarajevo_plan)

    mostar_plan = Plan.create!(title: "Mostar Plan", visibility: :public_plan, city_name: "Mostar")
    Browse.sync_record(mostar_plan)

    results = Browse.by_city_name("Sarajevo").plans
    assert_includes results.pluck(:browsable_id), sarajevo_plan.id
    assert_not_includes results.pluck(:browsable_id), mostar_plan.id

    sarajevo_plan.destroy
    mostar_plan.destroy
  end

  # === Edge case tests ===

  test "sync_record handles nil attributes gracefully" do
    # Create a minimal location
    location = Location.create!(
      name: "Minimal Location",
      city: nil,
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    Browse.sync_record(location)

    browse = Browse.find_by(browsable: location)
    assert_not_nil browse
    assert_nil browse.city_name

    location.destroy
  end

  test "chaining multiple scopes works correctly" do
    # Create test data
    location = create_test_location(
      name: "High Rated Summer Cafe",
      city: "Sarajevo",
      average_rating: 4.5,
      seasons: %w[summer],
      ai_generated: true
    )
    Browse.sync_record(location)
    Browse.find_by(browsable: location).update!(browsable_subtype: "cafe")

    # Chain multiple scopes
    results = Browse
      .locations
      .by_city_name("Sarajevo")
      .by_min_rating(4.0)
      .by_season("summer")
      .ai_generated
      .by_subtype("cafe")

    assert_includes results.pluck(:browsable_id), location.id

    location.destroy
  end
end

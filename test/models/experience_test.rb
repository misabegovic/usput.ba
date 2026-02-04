# frozen_string_literal: true

require "test_helper"

class ExperienceTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    @valid_params = {
      title: "Test Experience",
      description: "A test experience description"
    }
  end

  teardown do
    @location&.destroy
  end

  # === Validation tests ===

  test "valid experience is saved" do
    experience = Experience.new(@valid_params)
    assert experience.save
    experience.destroy
  end

  test "title is required" do
    experience = Experience.new(@valid_params.merge(title: nil))
    assert_not experience.valid?
    assert_includes experience.errors[:title], "can't be blank"
  end

  test "estimated_duration must be positive" do
    experience = Experience.new(@valid_params.merge(estimated_duration: 0))
    assert_not experience.valid?

    experience.estimated_duration = -10
    assert_not experience.valid?

    experience.estimated_duration = 60
    assert experience.valid?
  end

  test "estimated_duration can be nil" do
    experience = Experience.new(@valid_params.merge(estimated_duration: nil))
    assert experience.valid?
  end

  # === UUID generation tests ===

  test "uuid is generated on create" do
    experience = Experience.create!(@valid_params)
    assert experience.uuid.present?
    experience.destroy
  end

  # === Location management ===

  test "add_location adds location with position" do
    experience = Experience.create!(@valid_params)
    experience.add_location(@location, position: 1)

    assert_includes experience.locations, @location
    assert_equal 1, experience.experience_locations.first.position

    experience.destroy
  end

  test "add_location auto-increments position" do
    experience = Experience.create!(@valid_params)
    location2 = Location.create!(
      name: "Second Location",
      city: "Sarajevo",
      lat: 43.8570,
      lng: 18.4140
    )

    experience.add_location(@location)
    experience.add_location(location2)

    positions = experience.experience_locations.pluck(:position)
    assert_equal [ 1, 2 ], positions.sort

    experience.destroy
    location2.destroy
  end

  test "remove_location removes location" do
    experience = Experience.create!(@valid_params)
    experience.add_location(@location, position: 1)
    experience.remove_location(@location)

    assert_not_includes experience.locations, @location

    experience.destroy
  end

  test "reorder_locations updates positions" do
    experience = Experience.create!(@valid_params)
    location2 = Location.create!(
      name: "Second Location",
      city: "Sarajevo",
      lat: 43.8570,
      lng: 18.4140
    )

    experience.add_location(@location, position: 1)
    experience.add_location(location2, position: 2)

    # Reorder: swap positions
    experience.reorder_locations([ location2.id, @location.id ])

    experience.reload
    assert_equal 1, experience.experience_locations.find_by(location: location2).position
    assert_equal 2, experience.experience_locations.find_by(location: @location).position

    experience.destroy
    location2.destroy
  end

  test "locations_count returns correct count" do
    experience = Experience.create!(@valid_params)
    assert_equal 0, experience.locations_count

    experience.add_location(@location)
    assert_equal 1, experience.locations_count

    experience.destroy
  end

  # === Duration formatting ===

  test "formatted_duration returns nil when no duration" do
    experience = Experience.new(@valid_params)
    assert_nil experience.formatted_duration
  end

  test "formatted_duration formats minutes only" do
    experience = Experience.new(@valid_params.merge(estimated_duration: 45))
    assert_equal "45min", experience.formatted_duration
  end

  test "formatted_duration formats hours only" do
    experience = Experience.new(@valid_params.merge(estimated_duration: 120))
    assert_equal "2h", experience.formatted_duration
  end

  test "formatted_duration formats hours and minutes" do
    experience = Experience.new(@valid_params.merge(estimated_duration: 90))
    assert_equal "1h 30min", experience.formatted_duration
  end

  # === Season helpers ===

  test "seasons returns empty array by default" do
    experience = Experience.new(@valid_params)
    assert_equal [], experience.seasons
  end

  test "year_round? returns true when seasons empty" do
    experience = Experience.new(@valid_params)
    assert experience.year_round?
  end

  test "available_in_season? works correctly" do
    experience = Experience.new(@valid_params.merge(seasons: [ "summer", "spring" ]))
    assert experience.available_in_season?("summer")
    assert_not experience.available_in_season?("winter")
  end

  test "add_season adds valid season" do
    experience = Experience.create!(@valid_params)
    experience.add_season("summer")
    assert_includes experience.seasons, "summer"
    experience.destroy
  end

  test "add_season ignores invalid season" do
    experience = Experience.create!(@valid_params)
    experience.add_season("invalid")
    assert_not_includes experience.seasons, "invalid"
    experience.destroy
  end

  test "set_year_round! clears seasons" do
    experience = Experience.create!(@valid_params.merge(seasons: [ "summer" ]))
    experience.set_year_round!
    assert_equal [], experience.seasons
    experience.destroy
  end

  test "season_names returns humanized names" do
    experience = Experience.new(@valid_params.merge(seasons: [ "summer", "winter" ]))
    names = experience.season_names
    assert_includes names, "Summer"
    assert_includes names, "Winter"
  end

  test "season_names returns Year-round when empty" do
    experience = Experience.new(@valid_params)
    assert_equal [ "Year-round" ], experience.season_names
  end

  # === City helpers ===

  test "city returns first location city" do
    experience = Experience.create!(@valid_params)
    experience.add_location(@location)

    assert_equal "Sarajevo", experience.city

    experience.destroy
  end

  test "city returns nil without locations" do
    experience = Experience.new(@valid_params)
    assert_nil experience.city
  end

  test "cities returns unique cities from all locations" do
    experience = Experience.create!(@valid_params)
    experience.add_location(@location)

    mostar_location = Location.create!(
      name: "Mostar Place",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )
    experience.add_location(mostar_location)

    assert_includes experience.cities, "Sarajevo"
    assert_includes experience.cities, "Mostar"

    experience.destroy
    mostar_location.destroy
  end

  # === Category helpers ===

  test "category_name returns category name" do
    category = ExperienceCategory.create!(name: "Adventure", key: "adventure_exp")
    experience = Experience.new(@valid_params.merge(experience_category: category))

    assert_equal "Adventure", experience.category_name

    category.destroy
  end

  test "category_name returns nil without category" do
    experience = Experience.new(@valid_params)
    assert_nil experience.category_name
  end

  # === Contact info helpers ===

  test "has_contact_info? returns false when no contact info" do
    experience = Experience.new(@valid_params)
    assert_not experience.has_contact_info?
  end

  test "has_contact_info? returns true when contact_email present" do
    experience = Experience.new(@valid_params.merge(contact_email: "test@example.com"))
    assert experience.has_contact_info?
  end

  # === Nearby experiences ===

  test "nearby_featured returns experiences in same city" do
    exp1 = Experience.create!(@valid_params)
    exp1.add_location(@location)

    exp2 = Experience.create!(@valid_params.merge(title: "Another Experience"))
    location2 = Location.create!(
      name: "Another Place",
      city: "Sarajevo",
      lat: 43.8570,
      lng: 18.4140
    )
    exp2.add_location(location2)

    nearby = exp1.nearby_featured(limit: 3)
    assert_includes nearby, exp2

    exp1.destroy
    exp2.destroy
    location2.destroy
  end

  test "nearby_featured excludes self" do
    experience = Experience.create!(@valid_params)
    experience.add_location(@location)

    nearby = experience.nearby_featured(limit: 3)
    assert_not_includes nearby, experience

    experience.destroy
  end

  # === Scopes ===

  test "with_locations scope filters experiences with locations" do
    with_loc = Experience.create!(@valid_params)
    with_loc.add_location(@location)

    without_loc = Experience.create!(@valid_params.merge(title: "No Locations"))

    results = Experience.with_locations
    assert_includes results, with_loc
    assert_not_includes results, without_loc

    with_loc.destroy
    without_loc.destroy
  end

  test "by_duration scope filters by duration range" do
    short = Experience.create!(@valid_params.merge(title: "Short", estimated_duration: 30))
    medium = Experience.create!(@valid_params.merge(title: "Medium", estimated_duration: 120))
    long = Experience.create!(@valid_params.merge(title: "Long", estimated_duration: 240))

    assert_includes Experience.by_duration("short"), short
    assert_includes Experience.by_duration("medium"), medium
    assert_includes Experience.by_duration("long"), long

    short.destroy
    medium.destroy
    long.destroy
  end

  test "by_season scope filters by season" do
    summer = Experience.create!(@valid_params.merge(title: "Summer", seasons: [ "summer" ]))
    year_round = Experience.create!(@valid_params.merge(title: "Year Round", seasons: []))

    results = Experience.by_season("summer")
    assert_includes results, summer
    assert_includes results, year_round # year-round included

    summer.destroy
    year_round.destroy
  end

  test "by_city_name scope filters experiences with locations in city" do
    sarajevo_exp = Experience.create!(@valid_params)
    sarajevo_exp.add_location(@location)

    mostar_location = Location.create!(
      name: "Mostar Place",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )
    mostar_exp = Experience.create!(@valid_params.merge(title: "Mostar Exp"))
    mostar_exp.add_location(mostar_location)

    results = Experience.by_city_name("Sarajevo")
    assert_includes results, sarajevo_exp
    assert_not_includes results, mostar_exp

    sarajevo_exp.destroy
    mostar_exp.destroy
    mostar_location.destroy
  end
end

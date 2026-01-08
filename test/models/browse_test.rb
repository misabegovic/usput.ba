# frozen_string_literal: true

require "test_helper"

class BrowseTest < ActiveSupport::TestCase
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
end

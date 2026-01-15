# frozen_string_literal: true

require "test_helper"

class BrowseAdapterTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Museum",
      description: "A wonderful museum",
      historical_context: "Built in 1900",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      budget: :medium,
      tags: ["culture", "history"],
      seasons: ["spring", "summer", "fall", "winter"],
      ai_generated: false
    )

    @experience = Experience.create!(
      title: "City Walking Tour",
      description: "A guided tour of the city",
      estimated_duration: 120,
      seasons: ["spring", "summer"],
      ai_generated: true
    )
    @experience.add_location(@location, position: 1)

    @public_plan = Plan.create!(
      title: "Weekend in Sarajevo",
      city_name: "Sarajevo",
      notes: "Great plan for a weekend",
      visibility: :public_plan,
      ai_generated: false
    )
    @public_plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )

    @private_plan = Plan.create!(
      title: "Private Plan",
      city_name: "Mostar",
      visibility: :private_plan
    )
  end

  teardown do
    @private_plan&.destroy
    @public_plan&.destroy
    @experience&.destroy
    @location&.destroy
  end

  # === Location attribute tests ===

  test "attributes_for location returns correct structure" do
    attrs = BrowseAdapter.attributes_for(@location)

    assert_not_nil attrs
    assert_equal "Test Museum", attrs[:title]
    assert_equal "Sarajevo", attrs[:city_name]
    assert_equal 43.8563, attrs[:lat]
    assert_equal 18.4131, attrs[:lng]
    assert_equal 1, attrs[:budget] # medium = 1
    assert_equal false, attrs[:ai_generated]
  end

  test "attributes_for location includes description components" do
    attrs = BrowseAdapter.attributes_for(@location)

    assert_includes attrs[:description], "A wonderful museum"
    assert_includes attrs[:description], "Built in 1900"
    assert_includes attrs[:description], "Sarajevo"
    assert_includes attrs[:description], "culture history"
  end

  test "attributes_for location includes category_keys" do
    category = LocationCategory.create!(name: "Museum", key: "museum_browse_test")
    @location.add_category(category, primary: true)

    attrs = BrowseAdapter.attributes_for(@location)

    assert_includes attrs[:category_keys], "museum_browse_test"

    category.destroy
  end

  test "attributes_for location includes seasons" do
    attrs = BrowseAdapter.attributes_for(@location)

    assert_equal ["spring", "summer", "fall", "winter"], attrs[:seasons]
  end

  test "attributes_for location returns nil for contact types" do
    contact = Location.create!(
      name: "Tour Guide",
      city: "Sarajevo",
      lat: 43.86,
      lng: 18.42,
      location_type: :guide
    )

    attrs = BrowseAdapter.attributes_for(contact)

    assert_nil attrs

    contact.destroy
  end

  # === Experience attribute tests ===

  test "attributes_for experience returns correct structure" do
    attrs = BrowseAdapter.attributes_for(@experience)

    assert_not_nil attrs
    assert_equal "City Walking Tour", attrs[:title]
    assert_equal "Sarajevo", attrs[:city_name] # from first location
    assert_equal 43.8563, attrs[:lat]
    assert_equal 18.4131, attrs[:lng]
    assert_nil attrs[:budget] # experiences don't have budget
    assert_equal true, attrs[:ai_generated]
  end

  test "attributes_for experience includes description components" do
    attrs = BrowseAdapter.attributes_for(@experience)

    assert_includes attrs[:description], "A guided tour of the city"
    assert_includes attrs[:description], "Test Museum"
    assert_includes attrs[:description], "Sarajevo"
  end

  test "attributes_for experience includes seasons" do
    attrs = BrowseAdapter.attributes_for(@experience)

    assert_equal ["spring", "summer"], attrs[:seasons]
  end

  test "attributes_for experience with category" do
    category = ExperienceCategory.create!(name: "Adventure", key: "adventure_browse")
    @experience.update!(experience_category: category)

    attrs = BrowseAdapter.attributes_for(@experience)

    assert_includes attrs[:category_keys], "adventure_browse"
    assert_includes attrs[:description], "Adventure"

    category.destroy
  end

  test "attributes_for experience without locations" do
    empty_exp = Experience.create!(title: "Empty Experience")

    attrs = BrowseAdapter.attributes_for(empty_exp)

    assert_nil attrs[:city_name]
    assert_nil attrs[:lat]
    assert_nil attrs[:lng]

    empty_exp.destroy
  end

  # === Plan attribute tests ===

  test "attributes_for public plan returns correct structure" do
    attrs = BrowseAdapter.attributes_for(@public_plan)

    assert_not_nil attrs
    assert_equal "Weekend in Sarajevo", attrs[:title]
    assert_equal "Sarajevo", attrs[:city_name]
    assert_nil attrs[:budget] # plans don't have budget
    assert_equal false, attrs[:ai_generated]
  end

  test "attributes_for plan includes description components" do
    @public_plan.reload # Reload to get experiences association
    attrs = BrowseAdapter.attributes_for(@public_plan)

    assert_includes attrs[:description], "Great plan for a weekend"
    assert_includes attrs[:description], "Sarajevo"
    assert_includes attrs[:description], "City Walking Tour"
  end

  test "attributes_for plan includes aggregated seasons from experiences" do
    @public_plan.reload # Reload to get experiences association
    attrs = BrowseAdapter.attributes_for(@public_plan)

    assert_includes attrs[:seasons], "spring"
    assert_includes attrs[:seasons], "summer"
  end

  test "attributes_for private plan returns nil" do
    attrs = BrowseAdapter.attributes_for(@private_plan)

    assert_nil attrs
  end

  test "attributes_for plan uses first experience location coordinates" do
    @public_plan.reload # Reload to get experiences association
    attrs = BrowseAdapter.attributes_for(@public_plan)

    assert_equal 43.8563, attrs[:lat]
    assert_equal 18.4131, attrs[:lng]
  end

  # === Edge cases ===

  test "attributes_for returns nil for unknown record type" do
    attrs = BrowseAdapter.attributes_for("not a model")

    assert_nil attrs
  end

  test "attributes_for handles nil record" do
    attrs = BrowseAdapter.attributes_for(nil)

    assert_nil attrs
  end

  test "attributes_for handles location with nil description" do
    minimal = Location.create!(
      name: "Minimal",
      lat: 44.0,
      lng: 18.0
    )

    attrs = BrowseAdapter.attributes_for(minimal)

    assert attrs[:description].is_a?(String)

    minimal.destroy
  end

  test "attributes_for handles experience with nil description" do
    minimal = Experience.create!(title: "Minimal Experience")

    attrs = BrowseAdapter.attributes_for(minimal)

    assert attrs[:description].is_a?(String)

    minimal.destroy
  end

  test "attributes_for handles plan with no notes" do
    plan = Plan.create!(
      title: "No Notes Plan",
      city_name: "Tuzla",
      visibility: :public_plan
    )

    attrs = BrowseAdapter.attributes_for(plan)

    assert attrs[:description].is_a?(String)
    assert_includes attrs[:description], "Tuzla"

    plan.destroy
  end
end

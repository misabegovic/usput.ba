require "application_system_test_case"

# Selecting a second category must widen the deck, not swap it: the traveller is
# asking for "food or nature", and the nearest of either belongs at the top.
class ExploreCategoryCombineTest < ApplicationSystemTestCase
  setup do
    @food = ExperienceType.create!(key: "food", name: "Sys Food", active: true)
    @nature = ExperienceType.create!(key: "nature", name: "Sys Nature", active: true)
    # Near and far, in different tiles: combining has to surface the near one.
    @near = Location.create!(name: "Near Kafana", city: "Sarajevo", lat: 43.8563, lng: 18.4131,
                             suitable_experiences: [ @food.key ])
    @far = Location.create!(name: "Far Fortress", city: "Sarajevo", lat: 43.8700, lng: 18.4400,
                            suitable_experiences: [ @nature.key ])
  end

  teardown do
    [ @near, @far ].each { |location| location&.destroy }
    [ @food, @nature ].each { |type| type&.destroy }
  end

  def open_filters
    # The rail is desktop-only; the mobile toggle hides the same partial.
    toggle = all("button", text: I18n.t("explore_bosnia.filters.title")).first
    toggle&.click
  end

  def choose_category(tile_key)
    label = I18n.t("explore_bosnia.tiles.#{tile_key}")
    find("label", text: label, match: :first).click
  end

  test "a second category widens the deck instead of replacing the first" do
    visit explore_bosnia_experience_path("food_drinks", lat: 43.8563, lng: 18.4131)
    assert_text "Near Kafana", wait: 5

    open_filters
    choose_category("sport_nature")

    # Both tiles are now asked for, so both places belong in the deck — and the
    # nearest of the two leads it.
    assert_text "Far Fortress", wait: 5
    assert_text "Near Kafana", wait: 5
    assert_equal "Near Kafana", first("[data-plan-deck-target='card'] h2").text
  end

  test "entering on all categories, a press picks that one" do
    visit explore_bosnia_experience_path("all", lat: 43.8563, lng: 18.4131)
    assert_text "Near Kafana", wait: 5
    assert_text "Far Fortress", wait: 5

    open_filters
    choose_category("sport_nature")

    # Nothing is preselected, so the press is a choice of one category.
    assert_text "Far Fortress", wait: 5
    assert_no_text "Near Kafana"
  end
end

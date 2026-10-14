require "application_system_test_case"

# The tag select on explore in a real browser: choosing a tag reloads the
# results with only the places carrying it, and the url says which tag.
class ExploreTagFilterTest < ApplicationSystemTestCase
  setup do
    @historic = Location.create!(name: "Tag Fortress", city: "Jajce", lat: 44.34, lng: 17.27, tags: [ "historic" ])
    @food = Location.create!(name: "Tag Kafana", city: "Mostar", lat: 43.34, lng: 17.81, tags: [ "food" ])
    [ @historic, @food ].each { |location| Browse.sync_record(location) }
  end

  teardown do
    [ @historic, @food ].each { |location| location&.destroy }
  end

  test "choosing a tag narrows explore to the places carrying it" do
    visit explore_path(types: [ "location" ])
    assert_text "Tag Fortress"
    assert_text "Tag Kafana"

    click_once_wired("[data-explore-target='filterToggle']", "explore")
    find("[data-explore-target='tagSelect']").select("historic")

    assert_current_path(/tag=historic/)
    assert_text "Tag Fortress"
    assert_no_text "Tag Kafana"
    assert_equal "historic", find("[data-explore-target='tagSelect']", visible: :all).value
  end
end

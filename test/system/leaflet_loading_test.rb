require "application_system_test_case"

# Stimulus eager-loads every controller on every page, so a module-level import
# in a map controller puts 147 KB of Leaflet on the home page and the login
# page. The service exists to keep the library where a map is actually drawn,
# and only a browser can tell whether it did.
class LeafletLoadingTest < ApplicationSystemTestCase
  setup do
    @location = Location.create!(name: "Sys Kravice", city: "Ljubuški", lat: 43.155, lng: 17.609)
  end

  teardown do
    @location&.destroy
  end

  test "the home page never loads the mapping library" do
    visit root_path
    assert_selector "body [data-controller]"

    assert_equal "undefined", page.evaluate_script("typeof window.L"),
                 "the home page loaded Leaflet, which it has no map for"
  end

  test "the sign-in page never loads the mapping library" do
    visit login_path
    assert_selector "form"

    assert_equal "undefined", page.evaluate_script("typeof window.L"),
                 "the sign-in page loaded Leaflet, which it has no map for"
  end

  test "a place still draws its map, which means the library arrived" do
    visit location_path(@location)
    page.execute_script("sessionStorage.clear()")
    visit location_path(@location)

    assert_selector ".leaflet-container", wait: 10
    assert_equal "object", page.evaluate_script("typeof window.L")
  end
end

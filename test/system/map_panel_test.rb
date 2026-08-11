require "application_system_test_case"

# Opening one place after another on the map must rewrite the panel in place.
# A full page load loses the map, the zoom and the route the traveller was
# following, and the frame swap is the whole reason the panel is a frame.
class MapPanelTest < ApplicationSystemTestCase
  setup do
    @first = Location.create!(name: "Sys Bridge", city: "Mostar", lat: 43.337, lng: 17.815)
    # Far enough apart that the pins neither cluster nor overlap at the default
    # zoom, close enough that both sit in the viewport.
    @second = Location.create!(name: "Sys Mosque", city: "Mostar", lat: 43.3425, lng: 17.815)
  end

  teardown do
    @first&.destroy
    @second&.destroy
  end

  test "opening a second place rewrites the panel without reloading the page" do
    visit location_path(@first)
    # Session storage outlives a Capybara reset, so the catalogue another test
    # cached would be served instead of this one's places.
    page.execute_script("sessionStorage.clear()")
    visit location_path(@first)
    assert_selector "[data-controller='map']"

    # Survives an in-place update; a full page load wipes it.
    page.execute_script("window.__stillHere = true")

    find("[data-map-target='fullscreenButton']").click

    # Both places may start inside one cluster; clicking it zooms in and splits
    # them, which is also how a traveller reaches them.
    3.times do
      break if all(".leaflet-marker-icon:not(.marker-cluster)", wait: 2).size >= 2
      cluster = all(".marker-cluster").first
      break unless cluster

      cluster.click
      sleep 0.6
    end
    markers = all(".leaflet-marker-icon:not(.marker-cluster)", minimum: 2, wait: 5)

    # The frame belongs to the map the traveller is standing on, not to the
    # place the pin names — the deck repeats this component once per card.
    panel_frame = "map_panel_location_#{@first.id}"

    markers.first.click
    assert_selector "turbo-frame##{panel_frame} h1", wait: 5

    markers.last.click
    assert_selector "turbo-frame##{panel_frame} h1", wait: 5

    assert page.evaluate_script("window.__stillHere === true"),
           "clicking a second pin reloaded the page instead of rewriting the panel"
  end
end

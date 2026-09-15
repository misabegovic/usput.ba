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

    # The map draws its markers once the tiles settle, and under a full-suite
    # load that outlasts the two-second look below — which would then find no
    # marker and no cluster, give up on the first pass, and fail on an empty map.
    assert_selector ".leaflet-marker-icon", wait: 10

    # Both places may start inside one cluster; clicking it zooms in and splits
    # them, which is also how a traveller reaches them.
    3.times do
      break if all(".leaflet-marker-icon:not(.marker-cluster)", wait: 2).size >= 2
      cluster = all(".marker-cluster").first
      break unless cluster

      cluster.click
      sleep 0.6
    end
    markers = all(".leaflet-marker-icon:not(.marker-cluster)", minimum: 2)

    # The frame belongs to the map the traveller is standing on, not to the
    # place the pin names — the deck repeats this component once per card.
    panel_frame = "map_panel_location_#{@first.id}"

    markers.first.click
    assert_selector "turbo-frame##{panel_frame} h1"

    markers.last.click
    assert_selector "turbo-frame##{panel_frame} h1"

    assert page.evaluate_script("window.__stillHere === true"),
           "clicking a second pin reloaded the page instead of rewriting the panel"
  end
  test "a pin whose place is gone makes the map drop its cached catalogue" do
    visit location_path(@first)
    page.execute_script("sessionStorage.clear()")
    visit location_path(@first)
    assert_selector "[data-controller='map']"
    find("[data-map-target='fullscreenButton']").click
    assert_selector ".leaflet-marker-icon", wait: 10

    assert_selector ".leaflet-marker-icon:not(.marker-cluster)", count: 2

    # Retired behind the traveller's back: the pin is still on their map, and
    # tapping it asks the panel — a frame request, which is the path that answers
    # with the gone panel rather than redirecting the whole page.
    @second.update!(archived_at: Time.current)

    # Which marker belongs to which place is not addressable, so try them in
    # turn. The list is re-read on each pass: opening a panel — and the redraw
    # this test is about — both replace the markers, and a handle taken before
    # that points at a node no longer on the map.
    2.times do |index|
      pins = all(".leaflet-marker-icon:not(.marker-cluster)")
      break if pins.size <= index

      pins[index].click
      break if page.has_text?(I18n.t("locations.retired"), wait: 3)
    end

    assert_text I18n.t("locations.retired")

    # What the traveller sees: the dead pin leaves on its own. Asserted with
    # assert_selector rather than a count of `all`, because the redraw is a fetch
    # away and only assert_selector waits for it. Asserting the cache emptied
    # would be wrong twice over — the map refills it with the current list.
    assert_selector ".leaflet-marker-icon:not(.marker-cluster)", count: 1, wait: 10
  end
end

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

  # Without this the browser answers with the machine's real position, and the
  # deck orders correctly from an origin the test never meant — which is why the
  # nearest place led only on the runs where geolocation had not resolved yet.
  def stand_at(location)
    uri = URI.parse(page.current_url)
    browser = page.driver.browser
    browser.execute_cdp("Browser.grantPermissions", origin: "#{uri.scheme}://#{uri.host}:#{uri.port}",
                        permissions: [ "geolocation" ])
    browser.execute_cdp("Emulation.setGeolocationOverride", latitude: location.lat.to_f,
                        longitude: location.lng.to_f, accuracy: 5)
    # A plain refresh reloads the coordinates the first ask already handed into
    # the url — the machine's own — so the override would never be consulted.
    visit_without_position(uri)
  end

  def visit_without_position(uri)
    query = URI.decode_www_form(uri.query.to_s).reject { |key, _| %w[lat lng approx].include?(key) }
    visit [ uri.path, query.any? ? URI.encode_www_form(query) : nil ].compact.join("?")
    wait_for_position
  end

  # The page asks again with no coordinates in the url, and hands the answer back
  # by re-pointing the deck. Landing mid-click, that re-point replaces the deck a
  # filter press just asked for.
  def wait_for_position
    deadline = Time.now + Capybara.default_max_wait_time

    sleep 0.1 until page.evaluate_script("new URL(window.location.href).searchParams.has('lat')") ||
                    Time.now > deadline
    settle_deck
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
    stand_at(@near)
    assert_text "Near Kafana"

    open_filters
    choose_category("sport_nature")

    # Both tiles are now asked for, so both places belong in the deck — and the
    # nearest of the two leads it.
    assert_text "Far Fortress"
    assert_text "Near Kafana"
    # Read the order only once the frame has stopped re-rendering: a filter
    # change re-points it, and the card read in between is the previous deck's.
    settle_deck
    assert_equal "Near Kafana", first("[data-plan-deck-target='card'] h2").text
  end

  test "entering on all categories, a press picks that one" do
    visit explore_bosnia_experience_path("all", lat: 43.8563, lng: 18.4131)
    stand_at(@near)
    assert_text "Near Kafana"
    assert_text "Far Fortress"

    open_filters
    choose_category("sport_nature")

    # Nothing is preselected, so the press is a choice of one category.
    assert_text "Far Fortress"
    assert_no_text "Near Kafana"
  end
end

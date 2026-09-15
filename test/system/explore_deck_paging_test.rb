require "application_system_test_case"

# The deck's lazy next-page frame in a real browser: scrolling to the bottom of
# a full page has to deal the next one and, once the places run out, end.
class ExploreDeckPagingTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(username: "sys_pager", password: "password123")
    @type = ExperienceType.create!(key: "history", name: "Sys History", active: true)
    @locations = 12.times.map do |i|
      Location.create!(name: "Pager Spot #{i}", city: "Sarajevo",
                       lat: 43.85 + i * 0.001, lng: 18.41,
                       suitable_experiences: [ @type.key ])
    end
  end

  teardown do
    @user&.destroy
    @locations.each(&:destroy)
    @type&.destroy
  end

  def login
    sign_in_as("sys_pager")
  end

  # Without this the browser answers with the machine's own position and the deck
  # is dealt from somewhere this test never meant.
  def stand_at(lat, lng)
    uri = URI.parse(page.current_url)
    browser = page.driver.browser
    browser.execute_cdp("Browser.grantPermissions", origin: "#{uri.scheme}://#{uri.host}:#{uri.port}",
                        permissions: [ "geolocation" ])
    browser.execute_cdp("Emulation.setGeolocationOverride", latitude: lat, longitude: lng, accuracy: 5)
    page.refresh
  end

  def scroll_deck_to_bottom
    page.execute_script(<<~JS)
      const deck = document.querySelector("[data-controller='plan-deck']")
      deck.scrollTop = deck.scrollHeight
    JS
  end

  test "scrolling to the bottom of a full page deals the next one and then ends" do
    login
    visit explore_bosnia_experience_path("history", lat: 43.85, lng: 18.41)
    stand_at(43.85, 18.41)

    assert_selector "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 10, wait: 10

    5.times do
      scroll_deck_to_bottom
      sleep 0.5
    end

    assert_text I18n.t("explore_bosnia.deck_end"), wait: 10
    assert_selector "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 12
  end
end

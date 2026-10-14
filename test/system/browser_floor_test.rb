# frozen_string_literal: true

require "application_system_test_case"

class BrowserFloorSystemTest < ApplicationSystemTestCase
  test "a current browser runs the app and never sees the old-browser notice" do
    visit "/mine-check"

    assert page.evaluate_script("window.usputModernScript === true"), "the floor probe module ran"
    assert_selector "#browser-floor-notice", visible: :hidden
  end

  test "the app keeps working when the browser refuses storage, as private browsing can" do
    place = Location.create!(name: "Floor Bridge", city: "Mostar", lat: 43.337, lng: 17.815)

    # A browser of its own: the suite's shared one carries other tests' HTTP
    # cache (the map's catalogue answers 304 with whatever an earlier test
    # fetched), and this one's storage is broken on purpose.
    Capybara.using_session(:storage_refused) do
      # Before any page script: every read and write of storage throws.
      page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        for (const name of ["getItem", "setItem", "removeItem"]) {
          Storage.prototype[name] = function () { throw new DOMException("refused", "SecurityError") }
        }
      JS

      visit "/mine-check"

      # The banner slides up from below the window once its controller connects;
      # clicked through the page, since the headless window cuts off its bottom edge.
      assert_selector ".cookie-consent-banner.cookie-consent-visible"
      wait_for_controller "[data-controller='cookie-consent']", "cookie-consent"
      page.execute_script("document.querySelector(\"[data-action='click->cookie-consent#accept']\").click()")
      assert_no_selector ".cookie-consent-banner.cookie-consent-visible"
      assert_selector "#browser-floor-notice", visible: :hidden

      # The map caches its catalogue of places in session storage.
      visit location_path(place)
      # A click before the map controller connects is swallowed with no error.
      wait_for_controller "[data-controller~='map']", "map"
      find("[data-map-target='fullscreenButton']").click
      assert_selector ".leaflet-marker-icon", wait: 10
    end
  ensure
    place&.destroy
  end
end

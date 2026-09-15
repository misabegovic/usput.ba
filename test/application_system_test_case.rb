require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # One budget for the whole suite rather than ninety of them written by hand.
  # Sixty-six tests share one browser and one server, the app's slowest measured
  # response is 2.4s, and every assertion that carried its own five seconds was
  # an independent chance to lose that race — which is why the failing test was a
  # different one every run. Ten seconds is not patience for a broken app: a
  # broken assertion still fails, it just stops failing on the machine being busy.
  Capybara.default_max_wait_time = 10

  # The browser is shared by the whole suite and localStorage outlives a Capybara
  # session reset, so one test's device state — a dismissed cookie banner, a
  # travel store, a theme — decides what the next test opens onto. Cleared here
  # so every test starts on the same device rather than on whichever one ran
  # before it.
  # Runs ahead of every test's own teardown, which is the point: a test deletes
  # its moments while the browser still has their photos in flight, and Active
  # Storage then records a variant for a blob that is already gone. Leaving the
  # page first stops the asking; clearing the device stops one test's banner,
  # store or theme from deciding what the next one opens onto.
  def before_teardown
    if page.current_url.to_s.start_with?("http")
      page.execute_script("localStorage.clear(); sessionStorage.clear()")
      visit "about:blank"
    end
    super
  end

  # A server-rendered element exists long before the controller that gives it
  # behaviour, and a click that lands in between is swallowed with no error —
  # the menu simply never opens. Waits for the controller instance rather than
  # for the markup.
  def click_once_wired(selector, identifier)
    wait_for_controller(selector, identifier)
    find(selector, match: :first).click
  end

  # The deck re-points its own frame when the position lands and again on every
  # filter change, so a card found in between is detached before the click can
  # reach it. Says nothing about what the deck holds — an empty one is a real
  # state — only that it has stopped re-rendering.
  def settle_deck
    assert_no_selector "turbo-frame#explore_deck[busy]"
  end

  # The profile's moments arrive in a lazy turbo-frame, which fetches only once
  # it is scrolled into view. A headless window never scrolls there on its own,
  # so the tiles a test is waiting for would never be requested at all.
  def load_profile_moments
    page.execute_script("document.querySelector('#my-moments-frame')?.scrollIntoView()")
    assert_selector "#my-moments-frame [data-photo-gallery-target='thumbnail']", minimum: 1, wait: 10
  end

  # Submitting before the field values have landed posts a blank form, which
  # re-renders the login page — no error raised, the test simply never left it.
  # Assert the value is in before pressing, and press again if the page did not
  # move: under a full-suite load the first press can still be swallowed.
  def sign_in_as(username, password = "password123")
    visit login_path
    submit_login(username, password)
    return if page.has_no_current_path?(login_path, wait: 10)

    # Land back on the form before pressing again: a slow-but-successful sign-in
    # has already moved on, and the page it moved to carries no login form.
    visit login_path
    submit_login(username, password)
    assert_no_current_path login_path, wait: 10
  end

  def submit_login(username, password)
    assert_selector "form", wait: 10
    within "form" do
      fill_in "username", with: username
      fill_in "password", with: password
      assert_field "username", with: username
      click_button
    end
  end

  def wait_for_controller(selector, identifier)
    deadline = Time.now + Capybara.default_max_wait_time

    sleep 0.1 until wired?(selector, identifier) || Time.now > deadline
  end

  def wired?(selector, identifier)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(#{selector.to_json})
        return !!(el && window.Stimulus &&
                  window.Stimulus.getControllerForElementAndIdentifier(el, #{identifier.to_json}))
      })()
    JS
  end
end

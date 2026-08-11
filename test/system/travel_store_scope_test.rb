require "application_system_test_case"

# The store lived under one name for every account on the device, and signing
# out cleared only the Rails session — so the next traveller to sign in on a
# shared phone arrived to someone else's walk. The key lives in the browser, so
# only a browser can prove it: a request-level test posts straight past this.
class TravelStoreScopeTest < ApplicationSystemTestCase
  BARE_KEY = "usput_travel_profile"

  setup do
    @ana = User.create!(username: "sys_ana", password: "password123")
    @bob = User.create!(username: "sys_bob", password: "password123")
    @type = ExperienceType.create!(key: "sys_scope_history", name: "Sys Scope History", active: true)
    @location = Location.create!(name: "Sys Scope Bridge", city: "Mostar", lat: 43.337, lng: 17.815,
                                 suitable_experiences: [ @type.key ])
    @location.photos.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")),
                            filename: "real_image.jpg", content_type: "image/jpeg")
  end

  teardown do
    @ana&.destroy
    @bob&.destroy
    @location&.destroy
    @type&.destroy
  end

  def login(username)
    visit login_path
    within "form" do
      fill_in "username", with: username
      fill_in "password", with: "password123"
      click_button
    end
    assert_no_current_path login_path, wait: 5
  end

  # Drops the session without running the logout button's clear, which is the
  # traveller who closes the tab rather than signing out.
  def abandon_session
    page.driver.browser.manage.delete_all_cookies
  end

  # localStorage outlives a Capybara session reset, so a store another test left
  # behind would be adopted here and prove nothing.
  def start_fresh
    visit root_path
    page.execute_script("localStorage.clear()")
  end

  def profile_keys
    page.evaluate_script("Object.keys(localStorage).filter(key => key.startsWith('#{BARE_KEY}'))")
  end

  # localStorage does not promise an order, so the key is named by what it is
  # not — the bare one, and any traveller already accounted for.
  def scoped_keys(except: [])
    profile_keys - [ BARE_KEY ] - except
  end

  def seed_favorite(key, id)
    page.execute_script(<<~JS, key, id)
      const profile = JSON.parse(localStorage.getItem(arguments[0]) || "{}")
      profile.favorites = [ { id: arguments[1], type: "location", name: "Seeded" } ]
      localStorage.setItem(arguments[0], JSON.stringify(profile))
    JS
  end

  def stored_favorites(key)
    page.evaluate_script("(JSON.parse(localStorage.getItem(arguments[0]) || '{}').favorites || []).map(item => item.id)", key)
  end

  def stored_visits(key)
    page.evaluate_script("(JSON.parse(localStorage.getItem(arguments[0]) || '{}').visited || []).map(item => item.name)", key)
  end

  def stand_at(location)
    uri = URI.parse(page.current_url)
    browser = page.driver.browser
    browser.execute_cdp("Browser.grantPermissions", origin: "#{uri.scheme}://#{uri.host}:#{uri.port}", permissions: [ "geolocation" ])
    browser.execute_cdp("Emulation.setGeolocationOverride", latitude: location.lat.to_f, longitude: location.lng.to_f, accuracy: 5)
  end

  # The real guest walk, not a seeded store: the 100 m gate runs in the browser
  # and only a browser standing there can pass it.
  def guest_check_in
    visit explore_bosnia_path
    stand_at(@location)
    visit explore_bosnia_experience_path(@type.key, lat: @location.lat, lng: @location.lng)
    find("button", text: I18n.t("plans.start.mark_visited"), match: :first).click
    assert_text "Visited", wait: 5
  end

  test "each traveller gets their own store key and cannot read the other's" do
    start_fresh
    login("sys_ana")
    visit profile_page_path
    assert_selector "[data-controller~='travel-profile']", wait: 5

    assert_not_includes profile_keys, BARE_KEY, "expected a traveller-scoped store key, got #{profile_keys.inspect}"
    ana_key = scoped_keys.sole
    seed_favorite(ana_key, "ana-favourite")

    abandon_session

    login("sys_bob")
    visit profile_page_path
    assert_selector "[data-controller~='travel-profile']", wait: 5

    bob_key = scoped_keys(except: [ ana_key ]).sole
    assert_empty stored_favorites(bob_key)
    assert_equal [ "ana-favourite" ], stored_favorites(ana_key)
  end

  test "logging out clears that traveller's store and leaves the device's own settings" do
    start_fresh
    login("sys_ana")
    visit profile_page_path
    assert_selector "[data-controller~='travel-profile']", wait: 5
    ana_key = scoped_keys.sole

    page.execute_script(<<~JS)
      localStorage.setItem("theme", "dark")
      localStorage.setItem("audio_tour_locale", "en")
      localStorage.setItem("pwa_install_dismissed_until", "9999999999")
      localStorage.setItem("cookie_consent", "accepted")
      localStorage.setItem("#{BARE_KEY}", JSON.stringify({ visited: [ { id: "guest-walk" } ] }))
    JS

    click_button I18n.t("auth.logout", default: "Odjavi se")
    assert_no_selector "[data-controller~='travel-profile'][data-travel-profile-logged-in-value='true']", wait: 5

    assert_nil page.evaluate_script("localStorage.getItem(arguments[0])", ana_key)
    assert_equal "dark", page.evaluate_script("localStorage.getItem('theme')")
    assert_equal "en", page.evaluate_script("localStorage.getItem('audio_tour_locale')")
    assert_equal "9999999999", page.evaluate_script("localStorage.getItem('pwa_install_dismissed_until')")
    assert_equal "accepted", page.evaluate_script("localStorage.getItem('cookie_consent')")
    assert_equal [ "guest-walk" ], page.evaluate_script("JSON.parse(localStorage.getItem('#{BARE_KEY}')).visited.map(entry => entry.id)")
  end

  # A device that already holds a store from before the key carried the
  # traveller must not lose it — and must not leave it behind for the next
  # account either.
  test "a store written under the old key is adopted by the traveller who signs in" do
    start_fresh
    visit login_path
    page.execute_script(<<~JS)
      localStorage.setItem("#{BARE_KEY}", JSON.stringify({
        favorites: [ { id: "legacy-favourite", type: "location", name: "Legacy" } ],
        badges: [ { id: "first_visit", earnedAt: "2026-01-01T00:00:00.000Z" } ]
      }))
    JS

    within "form" do
      fill_in "username", with: "sys_ana"
      fill_in "password", with: "password123"
      click_button
    end
    assert_no_current_path login_path, wait: 5

    visit profile_page_path
    assert_selector "[data-controller~='travel-profile']", wait: 5

    adopted = scoped_keys.sole
    assert_equal [ "legacy-favourite" ], stored_favorites(adopted)
    assert_not_includes profile_keys, BARE_KEY
  end

  # The claim used to ride on reading the profile, and the profile is only read
  # where its controller mounts — never on the home page a traveller lands on
  # after signing in. Sign in, stay there, leave, and the walk sat under the bare
  # name waiting for the next account on the device to adopt it.
  test "a guest walk is claimed on sign-in even where the profile never mounts" do
    start_fresh
    guest_check_in
    assert_equal [ BARE_KEY ], profile_keys

    login("sys_ana")
    assert_current_path root_path
    assert_no_selector "[data-controller~='travel-profile']"

    assert_not_includes profile_keys, BARE_KEY, "expected the walk to be claimed, got #{profile_keys.inspect}"
    assert_equal [ @location.name ], stored_visits(scoped_keys.sole)

    abandon_session
    visit root_path

    assert_nil page.evaluate_script("localStorage.getItem('#{BARE_KEY}')")
  end

  # The other half of the same rule: an unscoped store is only claimable once
  # there is a traveller to claim it, so a walk nobody has signed in behind must
  # still be there when the browser comes back.
  test "a walk nobody has signed in behind stays under the bare key" do
    start_fresh
    guest_check_in

    visit root_path
    visit explore_bosnia_path

    assert_equal [ BARE_KEY ], profile_keys
    assert_equal [ @location.name ], stored_visits(BARE_KEY)
  end
end

require "application_system_test_case"

# Walking has to earn badges. Collapsing the location page's check-in into the
# shared control took both visit triggers with it, so badges arrived only when a
# favourite was added — and every request-level test passed through the gap,
# because the trigger only ever existed in the browser.
class VisitBadgesTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(username: "sys_walker", password: "password123")
    @type = ExperienceType.create!(key: "history", name: "Sys History", active: true)
    @location = Location.create!(name: "Sys Bridge", city: "Mostar", lat: 43.337, lng: 17.815,
                                 suitable_experiences: [ @type.key ])
    @location.photos.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")),
                            filename: "real_image.jpg", content_type: "image/jpeg")
  end

  teardown do
    @user&.destroy
    @location&.destroy
    @type&.destroy
  end

  def login
    visit login_path
    within "form" do
      fill_in "username", with: "sys_walker"
      fill_in "password", with: "password123"
      click_button
    end
    assert_no_current_path login_path, wait: 5
  end

  def visit_deck
    visit explore_bosnia_experience_path("history", lat: @location.lat, lng: @location.lng)
  end

  # A guest presses a plain button; a signed-in traveller submits a form.
  def check_in
    find("button", text: I18n.t("plans.start.mark_visited"), match: :first).click
  end

  def stand_at(location)
    uri = URI.parse(page.current_url)
    browser = page.driver.browser
    browser.execute_cdp("Browser.grantPermissions", origin: "#{uri.scheme}://#{uri.host}:#{uri.port}", permissions: [ "geolocation" ])
    browser.execute_cdp("Emulation.setGeolocationOverride", latitude: location.lat.to_f, longitude: location.lng.to_f, accuracy: 5)
  end

  # A signed-in traveller's store is keyed by the traveller, a guest's is not, so
  # the badges are read from whichever key this walk was written under.
  def stored_badges
    page.evaluate_script(<<~JS)
      (() => {
        const keys = Object.keys(localStorage).filter(name => name.startsWith('usput_travel_profile'))
        const key = keys.find(name => name !== 'usput_travel_profile') || keys[0]
        return (JSON.parse((key && localStorage.getItem(key)) || '{}').badges || []).map(badge => badge.id)
      })()
    JS
  end

  # localStorage outlives a Capybara session reset, so the guest walk below would
  # otherwise be adopted by the traveller who signs in for the next test.
  def start_fresh
    visit root_path
    page.execute_script("localStorage.clear()")
  end

  test "a guest earns the first-step badge by checking in" do
    start_fresh
    visit explore_bosnia_path
    stand_at(@location)
    visit_deck

    check_in
    assert_text "Visited", wait: 5

    assert_includes stored_badges, "first_visit"
  end

  test "a signed-in traveller earns the first-step badge by checking in" do
    start_fresh
    login
    visit explore_bosnia_path
    stand_at(@location)
    visit_deck

    check_in
    assert_text "Visited", wait: 5

    # The badge is decided from `visited`, which the server projects from
    # PlanVisit — so it is earned on the next screen carrying the profile.
    visit location_path(@location)

    assert_text I18n.t("travel_profile.new_badge"), wait: 5
    assert_includes stored_badges, "first_visit"
  end
end

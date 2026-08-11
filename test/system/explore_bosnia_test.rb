require "application_system_test_case"

# The explore browse deck in a real browser: the card's button checks in, tapping
# the card opens the menu, and the moments panel opens for anyone.
class ExploreBosniaSystemTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(username: "sys_explorer", password: "password123")
    @type = ExperienceType.create!(key: "history", name: "Sys History", active: true)
    @location = Location.create!(name: "Sys Fort", city: "Sarajevo", lat: 43.85, lng: 18.41,
                                 suitable_experiences: [ @type.key ])
    @location.photos.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")),
                            filename: "real_image.jpg", content_type: "image/jpeg")
  end

  # The window is shared across the suite, so the phone sizes below have to go
  # back or a later test finds the deck card it is looking for sized away.
  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    @user&.destroy
    @location&.destroy
    @type&.destroy
  end

  def login
    visit login_path
    within "form" do
      fill_in "username", with: "sys_explorer"
      fill_in "password", with: "password123"
      click_button
    end
    assert_no_current_path login_path, wait: 5
  end

  def check_in
    find("button[type=submit]", text: I18n.t("plans.start.mark_visited"), match: :first).click
  end

  def open_moments_panel
    page.execute_script("document.querySelector(\"[data-story-open]\")?.click()")
  end

  def visit_deck
    visit explore_bosnia_experience_path("history", lat: @location.lat, lng: @location.lng)
  end

  # Same CDP override the walk's system test uses.
  def stand_at(location)
    uri = URI.parse(page.current_url)
    browser = page.driver.browser
    browser.execute_cdp("Browser.grantPermissions", origin: "#{uri.scheme}://#{uri.host}:#{uri.port}", permissions: [ "geolocation" ])
    browser.execute_cdp("Emulation.setGeolocationOverride", latitude: location.lat.to_f, longitude: location.lng.to_f, accuracy: 5)
  end

  test "the check-in button stamps the card visited" do
    login
    visit explore_bosnia_path
    stand_at(@location)
    visit_deck

    check_in

    assert_text "Visited", wait: 5
    assert @user.plan_visits.joins(:plan).exists?(location: @location)
  end

  test "moments open from the menu without having visited the place" do
    login
    visit_deck

    find("[data-plan-deck-target='card'][data-plan-deck-lat]", match: :first).click
    assert_selector "[data-card-menu-target='menu']", visible: true, wait: 5
    find("button", text: I18n.t("plans.start.shared_moments"), match: :first).click

    assert_selector "[data-card-menu-target='panel'][data-panel='moments']", visible: true, wait: 5
    assert_selector "label[aria-label='#{I18n.t('plans.moments.add')}']", wait: 5
  end

  test "a card's moments wrap into rows and the panel scrolls through them" do
    plan = Plan.explore_bosnia_for(@user)
    7.times do
      moment = @user.moments.new(plan: plan, location: @location, visibility: :private_moment)
      moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")),
                          filename: "real_image.jpg", content_type: "image/jpeg")
      moment.save!
    end
    login
    visit_deck

    find("[data-plan-deck-target='card'][data-plan-deck-lat]", match: :first).click
    find("button", text: I18n.t("plans.start.shared_moments"), match: :first).click

    assert_selector "[data-photo-gallery-target='thumbnail']", count: 7, wait: 5
    rows = page.evaluate_script(<<~JS)
      (() => {
        const thumbs = Array.from(document.querySelectorAll("[data-photo-gallery-target='thumbnail']"))
        return new Set(thumbs.map((thumb) => Math.round(thumb.getBoundingClientRect().top))).size
      })()
    JS
    assert_operator rows, :>=, 3, "seven moments three across need at least three rows"

    overflow = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("[data-card-menu-target='panel'][data-panel='moments']")
        return getComputedStyle(panel).overflowY
      })()
    JS
    assert_equal "auto", overflow, "the panel has to scroll once the rows outgrow the card"
  end

  test "on a phone two filters can be pressed in a row without a page load" do
    page.driver.browser.manage.window.resize_to(390, 844)
    login
    visit_deck
    page.execute_script("window.__stayedPut = true")

    find("button[data-action='deck-filters#toggle']").click
    find("label", text: I18n.t("explore_bosnia.tiles.relax"), match: :first).click
    assert_current_path(/categories/, wait: 5)

    find("label", text: I18n.t("explore_bosnia.filters.seasons.winter"), match: :first).click
    assert_current_path(/season=winter/, wait: 5)
    assert page.evaluate_script("window.__stayedPut"), "the filters reloaded the page"
  end

  test "a phone can check in from the card" do
    page.driver.browser.manage.window.resize_to(390, 844)
    login
    visit explore_bosnia_path
    stand_at(@location)
    visit_deck

    check_in

    assert_text "Visited", wait: 5
    assert @user.plan_visits.joins(:plan).exists?(location: @location)
  end

  test "ticking a category on the desktop rail reloads the deck" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    login
    visit_deck

    within("aside[data-controller='deck-filters']") do
      find("label", text: I18n.t("explore_bosnia.tiles.relax"), match: :first).click
    end

    assert_current_path(/categories/, wait: 5)
  end

  test "a chosen filter can be pressed again to clear it" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    login
    visit explore_bosnia_experience_path("history", lat: @location.lat, lng: @location.lng, budget: "low")

    within("aside[data-controller='deck-filters']") do
      find("label", text: I18n.t("explore_bosnia.filters.budgets.low"), match: :first).click
    end

    assert_no_current_path(/budget=low/, wait: 5)
  end

  test "clear filters reloads the deck unfiltered" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    login
    visit explore_bosnia_experience_path("history", lat: @location.lat, lng: @location.lng, budget: "low")

    within("aside[data-controller='deck-filters']") do
      click_link I18n.t("explore_bosnia.filters.clear")
    end

    assert_no_current_path(/budget/, wait: 5)
  end

  test "tapping the card opens the menu" do
    login
    visit_deck

    find("[data-plan-deck-target='card'][data-plan-deck-lat]", match: :first).click

    assert_selector "[data-card-menu-target='menu']", visible: true, wait: 5
  end

  test "the moments panel opens from the card with the upload tile" do
    login
    visit explore_bosnia_path
    stand_at(@location)
    visit_deck
    check_in
    assert_text "Visited", wait: 5

    open_moments_panel

    assert_selector "[data-card-menu-target='panel'][data-panel='moments']", visible: true, wait: 5
    assert_selector "p", text: I18n.t("plans.start.story_none"), visible: :all
    assert_selector "label[aria-label='#{I18n.t('plans.moments.add')}']", visible: :all
  end
end

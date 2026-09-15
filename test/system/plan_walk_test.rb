require "application_system_test_case"

class PlanWalkTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(username: "sys_walker", password: "password123")
    @location = Location.create!(name: "Sys Loc", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @experience = Experience.create!(title: "Sys Exp", description: "desc")
    @experience.locations << @location
    @plan = Plan.create!(title: "Sys Plan", city_name: "Sarajevo", visibility: :private_plan, user: @user)
    @plan.plan_experiences.create!(experience: @experience, day_number: 1)
  end

  # Moments live behind the card menu now that no gesture opens them.
  def open_moments_panel
    find("[data-plan-deck-target='card'] button[data-action='card-menu#openFromHandle']", match: :first).click
    find("button", text: I18n.t("plans.start.shared_moments"), match: :first).click
  end

  # Real PointerEvents — Capybara cannot express a drag gesture, and the
  # controller listens for pointerdown/pointerup (finger and mouse alike).
  def swipe_on(selector, dx:, dy:)
    page.execute_script(<<~JS, selector, dx, dy)
      const [selector, dx, dy] = arguments
      const el = document.querySelector(selector)
      const startX = 20, startY = 20

      const fire = (type, x, y) => el.dispatchEvent(new PointerEvent(type, {
        pointerId: 1,
        isPrimary: true,
        pointerType: "touch",
        clientX: x,
        clientY: y,
        bubbles: true,
        cancelable: true
      }))

      fire("pointerdown", startX, startY)
      fire("pointerup", startX + dx, startY + dy)
    JS
  end

  def login
    sign_in_as("sys_walker")
  end

  # Put the headless browser at a real position so the geo-visit check passes —
  # the same override DevTools' Sensors panel applies by hand.
  def stand_at(location)
    uri = URI.parse(page.current_url)
    browser = page.driver.browser
    browser.execute_cdp("Browser.grantPermissions", origin: "#{uri.scheme}://#{uri.host}:#{uri.port}", permissions: [ "geolocation" ])
    browser.execute_cdp("Emulation.setGeolocationOverride", latitude: location.lat.to_f, longitude: location.lng.to_f, accuracy: 5)
    # The position service starts watching on connect, so the override has to be
    # in place before the page is: setting it afterwards races the first fix.
    page.refresh
  end

  test "the deck shows every plan stop, in plan order" do
    second = Location.create!(name: "Second Loc", city: "Sarajevo", lat: 43.90, lng: 18.50)
    @experience.locations << second
    login
    visit start_plan_path(@plan)

    # Browse deck (same as explore): every stop stays in the scroll, none hidden
    # behind a deal-one deck.
    assert_selector "##{ActionView::RecordIdentifier.dom_id(@location, :step)}", visible: true
    assert_selector "##{ActionView::RecordIdentifier.dom_id(second, :step)}", visible: true
  ensure
    second&.destroy
  end

  test "a visited stop stays in the deck, stamped, beside un-visited stops" do
    second = Location.create!(name: "Second Loc", city: "Sarajevo", lat: 43.86, lng: 18.42)
    @experience.locations << second
    @user.plan_visits.create!(plan: @plan, location: @location)
    login
    visit start_plan_path(@plan)

    # Both cards stay in the deck; the visited one is stamped, not hidden away.
    assert_selector "##{ActionView::RecordIdentifier.dom_id(@location, :step)}", visible: true
    assert_selector "##{ActionView::RecordIdentifier.dom_id(second, :step)}", visible: true
    assert_text "Visited"
  ensure
    second&.destroy
  end

  test "publishing a moment from the profile updates in place (no full reload)" do
    moment = @user.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    login
    visit profile_page_path
    load_profile_moments

    frame = "##{ActionView::RecordIdentifier.dom_id(moment)}"
    # Publishing lives in the viewer now, the same one every surface opens.
    find("#{frame} [data-photo-gallery-target='thumbnail']").click
    assert_selector "dialog[open]"
    within("[data-photo-gallery-target='captionVisibility']") { find("button[type=submit]").click }

    assert_selector frame, text: I18n.t("plans.start.story_pending")
    assert moment.reload.visibility_public_moment?, "the moment must be public after publishing"
  end

  test "deleting a moment from the profile removes its card in place" do
    moment = @user.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    login
    visit profile_page_path
    load_profile_moments

    frame = "##{ActionView::RecordIdentifier.dom_id(moment)}"
    assert_selector frame
    find("#{frame} [data-photo-gallery-target='thumbnail']").click
    assert_selector "dialog[open]"
    accept_confirm { within("[data-photo-gallery-target='captionDelete']") { find("button[type=submit]").click } }

    # The viewer held the moment that just went: it must not stay open on it.
    assert_no_selector "dialog[open]"
    assert_no_selector frame
    refute Moment.exists?(moment.id), "the moment must be gone from the database"
  end

  test "an admin marks the location visited in a single click, without standing there" do
    @user.update!(user_type: :admin)
    login
    visit start_plan_path(@plan)
    # Pinned well away from the place: an admin needs no geofence, and the
    # machine's real position should not be what decides that.
    stand_at(Location.new(lat: 45.0, lng: 20.0))

    click_button I18n.t("plans.start.mark_visited")

    assert_text "Visited"
  end

  test "mark visited then drop a photo in the moments panel, it appears without a reload" do
    login
    visit start_plan_path(@plan)
    stand_at(@location)

    click_button I18n.t("plans.start.mark_visited")
    assert_text "Visited"

    open_moments_panel
    assert_selector "[data-card-menu-target='panel'][data-panel='moments']", visible: true

    # The upload tile fronts a native picker Capybara can't drive; attach to the
    # sr-only field behind it.
    attach_file "moment[photo]", file_fixture("real_image.jpg").to_s, make_visible: true

    assert_selector "img[src*='/moments/']", visible: :all
  end

  test "the fullscreen moment closes on the X, even sitting over a swipeable card" do
    moment = @user.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    @user.plan_visits.create!(plan: @plan, location: @location)
    login
    visit start_plan_path(@plan)

    open_moments_panel
    assert_selector "[data-card-menu-target='panel'][data-panel='moments']", visible: true

    find("[data-photo-gallery-target='thumbnail']", match: :first).click
    assert_selector "[data-photo-gallery-target='lightbox']", visible: true

    within("[data-photo-gallery-target='lightbox']") { find("button[aria-label]", match: :first).click }

    assert_no_selector "[data-photo-gallery-target='lightbox']", visible: true
    refute @user.plan_visits.where(plan: @plan, location: @location).count > 1,
      "closing the lightbox must not reach the card underneath"
  end

  # A deck of any length used to build a Leaflet instance, a tile layer and a
  # document keydown listener per card before the traveller opened anything.
  test "the walk builds no map until a card's map panel is opened" do
    second = Location.create!(name: "Second Loc", city: "Sarajevo", lat: 43.90, lng: 18.50)
    @experience.locations << second
    login
    visit start_plan_path(@plan)
    assert_selector "##{ActionView::RecordIdentifier.dom_id(@location, :step)}"

    assert_equal 0, page.evaluate_script("document.querySelectorAll('.leaflet-container').length"),
      "a hidden card map must not mount Leaflet"

    find("[data-plan-deck-target='card'] button[data-action='card-menu#openFromHandle']", match: :first).click
    find("button", text: I18n.t("plans.start.map"), match: :first).click

    assert_selector "[data-card-menu-target='panel'][data-panel='map'] .leaflet-container", visible: true
    assert_equal 1, page.evaluate_script("document.querySelectorAll('.leaflet-container').length"),
      "only the opened card's map may mount"
  ensure
    second&.destroy
  end

  test "visited progress persists when leaving and returning to the walk" do
    login
    visit start_plan_path(@plan)
    stand_at(@location)
    click_button I18n.t("plans.start.mark_visited")
    assert_text "Visited"

    visit plan_path(@plan)
    visit start_plan_path(@plan)

    assert_text "Visited"
  end
end

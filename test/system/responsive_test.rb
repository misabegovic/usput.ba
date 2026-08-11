require "application_system_test_case"

# A page that scrolls sideways on a phone is broken, whatever it looks like on a
# laptop. Every public surface is walked at phone width and asserted not to
# overflow, so a stray fixed width or an unwrappable row fails here instead of
# on someone's handset.
class ResponsiveTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze  # iPhone 14
  TABLET = [ 768, 1024 ].freeze

  # The browser window is shared across the whole system suite, so it has to go
  # back or later tests find `hidden sm:block` controls invisible.
  teardown do
    resize_to(1400, 1400)
  end

  setup do
    @location = Location.create!(name: "Resp Loc", city: "Sarajevo", lat: 43.85, lng: 18.41,
                                 description: "A place for the responsive sweep.")
    @experience = Experience.create!(title: "Resp Exp", description: "desc")
    @experience.locations << @location
    @user = User.create!(username: "resp_walker", password: "password123")
    @plan = Plan.create!(title: "Resp Plan", city_name: "Sarajevo", visibility: :private_plan, user: @user)
    @plan.plan_experiences.create!(experience: @experience, day_number: 1)
  end

  teardown do
    @user&.destroy
    @experience&.destroy
    @location&.destroy
  end

  test "no public page scrolls sideways on a phone" do
    resize_to(*PHONE)

    each_public_page { |path| assert_no_horizontal_scroll(path) }
  end

  test "no public page scrolls sideways on a tablet" do
    resize_to(*TABLET)

    each_public_page { |path| assert_no_horizontal_scroll(path) }
  end

  # The hero clips its own overflow, so a button sitting on top of the photos
  # never shows up as a horizontal scroll — it has to be measured directly.
  # 740x910 is the width the operator caught it at: past sm, short of lg, where
  # the layout is still stacked.
  test "the hero buttons never overlap the hero photos" do
    [ [ 740, 910 ], [ 640, 900 ], [ 1023, 900 ] ].each do |width, height|
      resize_to(width, height)
      visit root_path

      overlap = page.evaluate_script(<<~JS)
        (() => {
          const hero = document.querySelector('[data-hero]')
          if (!hero) return -1
          const ctas = [...hero.querySelectorAll('a')]
          const photos = [...hero.querySelectorAll('img')]
          if (!ctas.length || !photos.length) return -1
          let worst = 0
          for (const c of ctas) {
            const a = c.getBoundingClientRect()
            if (a.width === 0) continue
            for (const p of photos) {
              const b = p.getBoundingClientRect()
              if (b.width === 0) continue
              const x = Math.min(a.right, b.right) - Math.max(a.left, b.left)
              const y = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top)
              if (x > 0 && y > 0) worst = Math.max(worst, Math.round(Math.min(x, y)))
            }
          }
          return worst
        })()
      JS

      refute_equal(-1, overlap, "could not find the hero CTA and photo at #{width}px")
      assert_equal 0, overlap, "hero CTA overlaps the photos by #{overlap}px at #{width}x#{height}"
    end
  end

  test "no signed-in page scrolls sideways on a phone" do
    login
    resize_to(*PHONE)

    each_signed_in_page { |path| assert_no_horizontal_scroll(path) }
  end

  test "no signed-in page scrolls sideways on a tablet" do
    login
    resize_to(*TABLET)

    each_signed_in_page { |path| assert_no_horizontal_scroll(path) }
  end

  # With the filter rail beside the deck, the middle of the screen is not the
  # middle of the card, and the hint has to follow the card.
  test "the deck hint centres on the card, not on the screen" do
    login
    resize_to(1400, 1000)
    visit explore_bosnia_experience_path("all", lat: @location.lat, lng: @location.lng)

    offsets = page.evaluate_script(<<~JS)
      (() => {
        const hint = document.querySelector("[data-deck-hint]")
        const card = document.querySelector("[data-plan-deck-target='card']")
        if (!hint || !card) return null
        const h = hint.getBoundingClientRect(), c = card.getBoundingClientRect()
        return {
          fromCard: Math.round(Math.abs((h.left + h.width / 2) - (c.left + c.width / 2))),
          fromScreen: Math.round(Math.abs((h.left + h.width / 2) - window.innerWidth / 2))
        }
      })()
    JS

    refute_nil offsets, "could not find the deck hint and a card"
    assert_operator offsets["fromCard"], :<=, 2,
      "the hint sits #{offsets["fromCard"]}px off the card's centre"
    assert_operator offsets["fromScreen"], :>, 2,
      "the rail should push the card off screen-centre, so the hint should be off it too"
  end

  private

  def login
    visit login_path
    within "form" do
      fill_in "username", with: @user.username
      fill_in "password", with: "password123"
      click_button
    end
    assert_no_current_path login_path, wait: 5
  end

  def each_signed_in_page
    [
      explore_bosnia_experience_path("all", lat: @location.lat, lng: @location.lng),
      explore_bosnia_experience_path("history", lat: @location.lat, lng: @location.lng),
      start_plan_path(@plan),
      plan_path(@plan),
      profile_page_path,
      profile_plans_path
    ].each { |path| yield path }
  end

  def each_public_page
    [
      root_path,
      explore_path,
      explore_bosnia_path,
      location_path(@location),
      experience_path(@experience),
      login_path
    ].each { |path| yield path }
  end

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def assert_no_horizontal_scroll(path)
    visit path
    # The banner and any fixed overlay are excluded by measuring the document,
    # which is what actually scrolls.
    overflow = page.evaluate_script(
      "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    assert overflow <= 1, "#{path} overflows horizontally by #{overflow}px"
  end
end

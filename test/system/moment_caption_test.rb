require "application_system_test_case"

# The moment view in a real browser. Every control here is reachable only
# through the UI, and a markup assertion would pass on a caption that never
# fills and a heart wired to nothing — so each one is clicked.
class MomentCaptionTest < ApplicationSystemTestCase
  setup do
    @author = User.create!(username: "cap_author", password: "password123")
    @reader = User.create!(username: "cap_reader", password: "password123")
    @location = Location.create!(name: "Caption Falls", city: "Jajce", lat: 44.34, lng: 17.27)
    @plan = Plan.create!(title: "Caption Plan", city_name: "Jajce", visibility: :private_plan, user: @author)
    @moments = 2.times.map { |i| public_moment("worth the walk #{i}") }
    @moments.each { |m| Browse.sync_record(m) }
  end

  teardown do
    Like.destroy_all
    Moment.destroy_all
    Browse.delete_all
    @plan&.destroy
    @location&.destroy
    @author&.destroy
    @reader&.destroy
  end

  test "opening a moment names its author and links to its place" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    open_first_moment

    assert_selector "[data-photo-gallery-target='captionAuthor']", text: "cap_author"
    assert_selector "[data-photo-gallery-target='captionPlaceName']", text: "Caption Falls"
    assert_selector "[data-photo-gallery-target='captionNote']", text: "worth the walk"

    find("[data-photo-gallery-target='captionPlace']").click
    assert_current_path location_path(@location)
  end

  test "swiping to the next moment carries the caption with it" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    open_first_moment
    first_note = find("[data-photo-gallery-target='captionNote']").text

    find("button[data-action='photo-gallery#next']").click

    assert_no_selector "[data-photo-gallery-target='captionNote']", text: first_note
  end

  test "the heart fills when liked and empties when taken back" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    open_first_moment

    heart = find("[data-photo-gallery-target='captionLike']")
    assert_equal "false", heart.reload[:"data-liked"]

    heart.click
    assert_selector "[data-photo-gallery-target='captionLike'][data-liked='true']"
    assert_equal 1, Like.count

    find("[data-photo-gallery-target='captionLike']").click
    assert_selector "[data-photo-gallery-target='captionLike'][data-liked='false']"
    assert_equal 0, Like.count
  end

  test "a guest tapping the heart is taken to sign in and brought back" do
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      first("a[aria-label='#{I18n.t("explore.moment_like_sign_in")}']", wait: 10).click
    end

    assert_current_path(/#{Regexp.escape(login_path)}/)

    within "form" do
      fill_in "username", with: "cap_reader"
      fill_in "password", with: "password123"
      click_button
    end

    # Both signing in and registering honour return_to, so the traveller lands
    # back where the heart was rather than on the home page.
    assert_current_path(/explore/)
    assert_equal 0, Like.count
  end

  test "an arrow key moves only the gallery whose viewer is open" do
    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    # Both bands render: the author's own moments and the public ones.
    assert_selector "[data-load-more-resource-type-value='my_moments']", wait: 10

    open_first_moment
    public_counter = find_all("[data-photo-gallery-target='lightboxCounter']").map(&:text)

    find("body").send_keys(:arrow_right)

    moved = find_all("[data-photo-gallery-target='lightboxCounter']").map(&:text)
    changed = public_counter.zip(moved).count { |before, after| before != after }
    assert_equal 1, changed, "one arrow key must move exactly one gallery"
  end

  test "the owner publishes from the edit view and the tile comes back agreeing" do
    private_one = @author.moments.build(plan: @plan, location: @location, note: "not shared yet")
    private_one.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "priv.jpg",
                             content_type: "image/jpeg")
    private_one.save!

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      first("button", text: I18n.t("plans.moments.edit_moment"), wait: 10).click
      click_button I18n.t("plans.start.story_publish")
    end

    # Publishing re-enters moderation by design, so the tile the edit view was
    # opened from comes back carrying the pending badge, without a reload.
    assert_selector "[data-load-more-resource-type-value='my_moments']",
                    text: I18n.t("plans.start.story_pending")
    assert private_one.reload.visibility_public_moment?
  end

  test "swiping off the last loaded moment fetches the next page instead of wrapping" do
    4.times { |i| Browse.sync_record(public_moment("edge #{i}")) }

    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      assert_selector "[data-photo-gallery-target='thumbnail']", count: 3, wait: 10
      first("[data-photo-gallery-target='thumbnail']").click

      2.times { find("button[data-action='photo-gallery#next']").click }
      # The third step is the one at the edge: it must load, not wrap to the first.
      find("button[data-action='photo-gallery#next']").click

      assert_selector "[data-photo-gallery-target='thumbnail']", minimum: 4, wait: 10
    end
  end

  test "the heart on the card likes without opening the photo" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      first("a[aria-pressed='false']", wait: 10).click
      assert_selector "a[aria-pressed='true']"
    end

    assert_equal 1, Like.count
  end

  test "the owner deletes from the edit view and the tile goes with it" do
    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      assert_selector "turbo-frame[id^='moment_']", count: 2, wait: 10
      first("button", text: I18n.t("plans.moments.edit_moment")).click
      accept_confirm { find("button[aria-label='#{I18n.t("plans.start.story_delete")}']").click }
      assert_selector "turbo-frame[id^='moment_']", count: 1
    end

    assert_equal 1, Moment.count
  end

  test "opening your own moment lets you rewrite its note there" do
    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      first("button", text: I18n.t("plans.moments.edit_moment"), wait: 10).click
      assert_selector "[data-photo-gallery-target='captionNoteField']", visible: true
      find("[data-photo-gallery-target='captionNoteField']").set("rewritten on the spot")
      click_button I18n.t("plans.moments.note_save")

      # The response rewrites the tile, which is how we know the round-trip
      # finished — asserting the database straight after the click races it.
      assert_text "rewritten on the spot"
    end

    assert_equal 1, Moment.where(note: "rewritten on the spot").count
  end

  test "the counter names the whole collection, not the loaded page" do
    2.times { |i| Browse.sync_record(public_moment("counted #{i}")) }

    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      assert_selector "[data-photo-gallery-target='thumbnail']", count: 3, wait: 10
      first("[data-photo-gallery-target='thumbnail']").click

      # Four exist, three are loaded. Reading "1 / 3" would say the traveller
      # has seen everything when they have seen a page.
      assert_selector "[data-photo-gallery-target='lightboxCounter']", text: "1 / 4"
    end
  end

  test "leaving through the place link and coming back leaves the page usable" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    open_first_moment
    find("[data-photo-gallery-target='captionPlace']").click
    assert_current_path location_path(@location)

    page.go_back
    assert_current_path(/explore/)

    # The viewer navigated away while open. If its teardown did not run before
    # Turbo cached the body, the restored page is locked against scrolling.
    assert_equal false, page.evaluate_script("document.body.classList.contains('overflow-hidden')")
    assert_no_selector "dialog[open]"

    open_first_moment
    assert_selector "[data-photo-gallery-target='captionAuthor']", text: "cap_author"
  end

  test "a private moment shows no heart on the card or in the viewer" do
    private_one = @author.moments.build(plan: @plan, location: @location, note: "mine alone")
    private_one.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "mine.jpg",
                             content_type: "image/jpeg")
    private_one.save!

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    # The private one is newest, so it is the first tile. Its neighbours are
    # public and rightly carry hearts, so the assertion is scoped to this tile.
    within first("turbo-frame[id^='moment_']", wait: 10) do
      assert_no_selector "a[aria-pressed]"
      find("[data-photo-gallery-target='thumbnail']").click
    end

    assert_selector "dialog[open]"
    # A private moment must show no heart the traveller can press.
    assert_no_selector "[data-photo-gallery-target='captionLike']"
  end

  test "swiping from a liked public moment to a private one drops the heart" do
    private_one = @author.moments.build(plan: @plan, location: @location, note: "mine alone")
    private_one.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "mine.jpg",
                             content_type: "image/jpeg")
    private_one.save!
    @author.likes.create!(likeable: @moments.first)

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      # Newest first, so the private one is the tile before the liked public one.
      all("[data-photo-gallery-target='thumbnail']", wait: 10)[1].click
      assert_selector "[data-photo-gallery-target='captionLike']"

      find("button[data-action='photo-gallery#previous']").click
      # The heart must not survive the swipe onto a private moment.
      assert_no_selector "[data-photo-gallery-target='captionLike']"
      # And it must not keep the previous moment's url while it waits.
      assert_nil find("[data-photo-gallery-target='captionLike']", visible: :all)[:href]
      assert_equal "", find("[data-photo-gallery-target='captionLikeCount']", visible: :all).text(:all).strip
    end
  end

  test "edit on the second tile opens that moment, not the first" do
    # Two private moments, newest first. The second tile is the older one.
    %w[older newer].each do |which|
      m = @author.moments.build(plan: @plan, location: @location, note: "private #{which}")
      m.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "#{which}.jpg",
                     content_type: "image/jpeg")
      m.save!
    end

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      buttons = all("button", text: I18n.t("plans.moments.edit_moment"), wait: 10)
      buttons[1].click
    end

    assert_selector "dialog[open]"
    assert_equal "private older",
                 find("[data-photo-gallery-target='captionNoteField']", visible: true).value,
                 "the viewer must open on the moment whose edit button was pressed"
  end

  test "liking in the viewer shows on the card once you close it" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      first("[data-photo-gallery-target='thumbnail']", wait: 10).click
      find("[data-photo-gallery-target='captionLike']").click
      assert_selector "[data-photo-gallery-target='captionLike'][data-liked='true']"

      find("button[data-action='photo-gallery#closeLightbox']").click
      assert_no_selector "dialog[open]"

      # The card behind the viewer must agree with what was just done to it.
      assert_selector "[data-load-more-target='container'] a[aria-pressed='true']"
    end
  end

  test "liking from the card shows in the viewer when you open it" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      first("a[aria-pressed='false']", wait: 10).click
      assert_selector "a[aria-pressed='true']"

      first("[data-photo-gallery-target='thumbnail']").click
      assert_selector "dialog[open]"

      # The viewer reads the tile, so the tile has to have heard about it too.
      assert_selector "[data-photo-gallery-target='captionLike'][data-liked='true']"
      assert_equal "1", find("[data-photo-gallery-target='captionLikeCount']").text.strip
    end
  end

  test "the author likes their own public moment from the card and unlikes it inside" do
    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      first("a[aria-pressed='false']", wait: 10).click
      assert_selector "a[aria-pressed='true']"

      first("[data-photo-gallery-target='thumbnail']").click
      assert_selector "[data-photo-gallery-target='captionLike'][data-liked='true']"

      find("[data-photo-gallery-target='captionLike']").click
      assert_selector "[data-photo-gallery-target='captionLike'][data-liked='false']"
    end

    assert_equal 0, Like.count, "the unlike must reach the database, not just the heart"
  end

  test "saving a note says so, and the message does not linger" do
    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      first("button", text: I18n.t("plans.moments.edit_moment"), wait: 10).click
      find("[data-photo-gallery-target='captionNoteField']").set("said and gone")
      click_button I18n.t("plans.moments.note_save")

      assert_selector "[data-photo-gallery-target='captionStatus']",
                      text: I18n.t("plans.moments.note_saved")
      assert_text "said and gone"
      # Said once: it clears itself rather than being stored anywhere.
      assert_no_selector "[data-photo-gallery-target='captionStatus']",
                         text: I18n.t("plans.moments.note_saved"), wait: 8
    end

    assert_equal 1, Moment.where(note: "said and gone").count
  end

  test "a first note stays in the field after saving" do
    blank = @author.moments.build(plan: @plan, location: @location)
    blank.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "blank.jpg",
                       content_type: "image/jpeg")
    blank.save!

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='my_moments']" do
      first("button", text: I18n.t("plans.moments.edit_moment"), wait: 10).click
      find("[data-photo-gallery-target='captionNoteField']").set("first words")
      click_button I18n.t("plans.moments.note_save")

      assert_selector "[data-photo-gallery-target='captionStatus']",
                      text: I18n.t("plans.moments.note_saved")
      # What was saved must still be in the box that saved it.
      assert_equal "first words",
                   find("[data-photo-gallery-target='captionNoteField']").value
    end
  end

  test "going back from the first moment stays put rather than jumping to the last loaded" do
    2.times { |i| Browse.sync_record(public_moment("wrap #{i}")) }

    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    within "[data-load-more-resource-type-value='moments']" do
      assert_selector "[data-photo-gallery-target='thumbnail']", count: 3, wait: 10
      first("[data-photo-gallery-target='thumbnail']").click
      assert_selector "[data-photo-gallery-target='lightboxCounter']", text: "1 / 4"

      find("button[data-action='photo-gallery#previous']").click

      # Four exist and three are loaded, so the last loaded is not the last:
      # wrapping would land on 3 / 4 and call it the end.
      assert_selector "[data-photo-gallery-target='lightboxCounter']", text: "1 / 4"
    end
  end

  test "opening a moment puts its own address in the bar, and closing gives it back" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])
    surface = page.current_url

    open_first_moment

    assert_match(%r{/moments/[0-9a-f-]{36}\z}, page.current_url)

    find("[data-action='photo-gallery#closeLightbox']", match: :first).click
    assert_no_selector "dialog[open]"
    assert_equal surface, page.current_url
  end

  test "a private moment shows its own address but offers no link to share" do
    private_one = @author.moments.build(plan: @plan, location: @location, note: "mine alone")
    private_one.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "mine.jpg",
                             content_type: "image/jpeg")
    private_one.save!

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within first("turbo-frame[id^='moment_']", wait: 10) do
      find("[data-photo-gallery-target='thumbnail']").click
    end

    assert_selector "dialog[open]"
    assert_current_path moment_path(private_one.public_id)
    assert_no_selector "[data-photo-gallery-target='captionShare']", visible: true
  end

  test "a heart pressed on the moment's own page fills without a reload" do
    login_as("cap_reader")
    visit moment_path(@moments.last.public_id)

    # The address opens the viewer over the grid, so the heart to press is the
    # caption's, not the tile's behind it.
    assert_selector "dialog[open]"
    within("dialog[open]") { find("[aria-pressed='false']").click }

    # Replaced in place: the frame comes back filled and the page never left.
    assert_selector "[aria-pressed='true']"
    assert_current_path moment_path(@moments.last.public_id)
    assert_equal 1, @moments.last.reload.likes_count
  end

  test "the profile opens its moments in the same viewer, with the owner's controls" do
    login_as("cap_author")
    visit profile_page_path
    load_profile_moments

    find("#my-moments-frame [data-photo-gallery-target='thumbnail']", match: :first).click

    assert_selector "dialog[open]"
    assert_selector "[data-photo-gallery-target='captionVisibility']", visible: true
    assert_selector "[data-photo-gallery-target='captionDelete']", visible: true
  end

  test "the profile tile carries no publish or delete of its own" do
    login_as("cap_author")
    visit profile_page_path
    load_profile_moments
    assert_no_selector "form[action*='unpublish']"
    assert_no_selector "form[action*='publish']"
  end

  test "the viewer offers a link to the moment, wherever it was opened from" do
    login_as("cap_reader")
    visit explore_path(types: [ "moment" ])

    open_first_moment

    assert_selector "[data-photo-gallery-target='captionShare']", visible: true
  end

  test "a private moment offers no link in the viewer" do
    private_one = @author.moments.build(plan: @plan, location: @location, note: "mine alone")
    private_one.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "mine.jpg",
                             content_type: "image/jpeg")
    private_one.save!

    login_as("cap_author")
    visit explore_path(types: [ "moment" ])

    within first("turbo-frame[id^='moment_']", wait: 10) do
      find("[data-photo-gallery-target='thumbnail']").click
    end

    assert_selector "dialog[open]"
    assert_no_selector "[data-photo-gallery-target='captionShare']", visible: true
  end

  private

  def open_first_moment
    first("[data-photo-gallery-target='thumbnail'][data-moment-author]", wait: 10).click
    assert_selector "dialog[open]"
  end

  def login_as(username)
    sign_in_as(username)
  end

  def public_moment(note)
    moment = @author.moments.build(plan: @plan, location: @location, note: note)
    moment.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "cap.jpg",
                        content_type: "image/jpeg")
    moment.save!
    moment.update_columns(visibility: Moment.visibilities[:public_moment],
                          moderation_status: Moment.moderation_statuses[:approved])
    moment.reload
  end
end

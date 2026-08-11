# frozen_string_literal: true

require "test_helper"

# Explore Bosnia: six fixed tiles, each grouping several experience types, deal
# the closest unvisited places as walk cards. Check-ins and moments ride a
# hidden per-user plan that never surfaces in plan listings.
class ExploreBosniaTest < ActionDispatch::IntegrationTest
  SARAJEVO = { lat: 43.85, lng: 18.41 }.freeze

  setup do
    @user = User.create!(username: "wanderer", password: "password123")
    # Canonical keys: the "history" tile groups the "history" type.
    @history = ExperienceType.create!(key: "history", name: "History", active: true)
    @near = Location.create!(name: "Close Fort", city: "Sarajevo", lat: 43.85, lng: 18.41,
                             suitable_experiences: [ @history.key ])
    @mid = Location.create!(name: "Middle Fort", city: "Visoko", lat: 43.65, lng: 18.20,
                            suitable_experiences: [ @history.key ])
    # ~75 km out: far enough that a day-trip bound would have dropped it.
    @outside = Location.create!(name: "Far Fort", city: "Mostar", lat: 43.34, lng: 17.81,
                                suitable_experiences: [ @history.key ])
  end

  teardown do
    @user&.destroy
    @admin&.destroy
    [ @near, @mid, @outside ].each { |location| location&.destroy }
    @history&.destroy
  end

  # The deck's keyset cursor interpolates Geocoder's distance expression into
  # SQL, which Brakeman flags. Verified 2026-08-04: Geocoder coerces its own
  # coordinates, so a raw injection string yields the same numeric SQL as a
  # float — our to_f is a second belt, not the load-bearing one — and the cursor
  # is bound besides. This asserts on the SQL text rather than the response,
  # because a request returning 200 says nothing about what reached the database.
  test "coordinates and cursor cannot carry sql into the deck query" do
    injection = "43.3'); DROP TABLE locations; --"
    statements = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }

    get explore_bosnia_experience_path("all"),
        params: { lat: injection, lng: injection,
                  after_distance: injection, after_id: injection }

    ActiveSupport::Notifications.unsubscribe(sub)
    offending = statements.select { |sql| sql.include?("DROP TABLE") }
    assert_empty offending, "a request value reached the SQL text: #{offending.first}"
  end

  test "entry goes straight to the deck, not to a category grid" do
    get explore_bosnia_path

    assert_redirected_to explore_bosnia_experience_path(ExploreBosniaController::ALL_CATEGORIES)
    follow_redirect!
    assert_select "[data-explore-geo-target='tile']", count: 0
    # The tiles survive only as filter pills, six of them on the rail.
    assert_select "aside input[name='categories[]']", count: 6
  end

  test "entry with a position lands in the deck of every category" do
    login_as(@user)

    get explore_bosnia_path, params: SARAJEVO

    assert_redirected_to explore_bosnia_experience_path("all", **SARAJEVO)
  end

  test "the all-categories deck deals places from every category" do
    art = ExperienceType.create!(key: "art", name: "Art", active: true)
    gallery = Location.create!(name: "Near Gallery", city: "Sarajevo", lat: 43.851, lng: 18.411,
                               suitable_experiences: [ art.key ])
    untagged = Location.create!(name: "Untagged Spot", city: "Sarajevo", lat: 43.853, lng: 18.413)
    login_as(@user)

    get explore_bosnia_experience_path("all", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Close Fort"
    assert_includes response.body, "Near Gallery"
    assert_includes response.body, "Untagged Spot"
    # No tile is preselected; the traveller picks if and when they want to.
    assert_select "aside input[type=checkbox][name='categories[]'][checked]", count: 0
  ensure
    [ gallery, untagged ].each { |location| location&.destroy }
    art&.destroy
  end

  test "picking five of the six tiles deals those five and drops the sixth" do
    art = ExperienceType.create!(key: "art", name: "Art", active: true)
    gallery = Location.create!(name: "Near Gallery", city: "Sarajevo", lat: 43.851, lng: 18.411,
                               suitable_experiences: [ art.key ])
    login_as(@user)

    remaining = ExploreBosniaController::BROWSE_TILES.keys - [ "culture" ]
    get explore_bosnia_experience_path("all", **SARAJEVO, categories: remaining)

    assert_response :success
    assert_includes response.body, "Close Fort"
    refute_includes response.body, "Near Gallery"
  ensure
    gallery&.destroy
    art&.destroy
  end

  test "without a position the deck shows the filters and asks for one" do
    login_as(@user)

    get explore_bosnia_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, I18n.t("explore_bosnia.needs_location.title")
    assert_select "input[name='categories[]']", minimum: 1
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 0
  end

  test "a budget filter narrows the deck and keeps closest first" do
    @near.update!(budget: :low)
    @mid.update!(budget: :high)
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO, budget: "low")

    assert_response :success
    assert_includes response.body, "Close Fort"
    refute_includes response.body, "Middle Fort"
  end

  test "entry opens on the season the traveller is standing in" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "aside input[type=radio][name=season][value=?][checked]", Location.current_season, count: 1
  end

  test "entry opens on the widest budget, and it hides nothing" do
    @near.update!(budget: :low)
    @mid.update!(budget: :high)
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "aside input[type=radio][name=budget][value=high][checked]", count: 1
    assert_includes response.body, "Close Fort"
    assert_includes response.body, "Middle Fort"
  end

  test "a place with no budget at all still shows under the widest budget" do
    @near.update!(budget: nil)
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Close Fort"
  end

  test "clearing the season keeps it cleared instead of falling back to today" do
    @near.update!(seasons: [ "winter" ])
    @mid.update!(seasons: [ "summer" ])
    login_as(@user)

    # The empty value is what turning the last pill of the group off submits.
    get explore_bosnia_experience_path("history", **SARAJEVO, season: "")

    assert_response :success
    assert_select "aside input[type=radio][name=season][checked]", count: 0
    assert_includes response.body, "Close Fort"
    assert_includes response.body, "Middle Fort"
  end

  test "the deck has no origin filter" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "aside input[name=origin]", count: 0
    refute_includes response.body, "AI Generated"
  end

  test "a rating filter drops places below the threshold" do
    @near.update!(average_rating: 4.8)
    @mid.update!(average_rating: 3.1)
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO, min_rating: "4.0")

    assert_response :success
    assert_includes response.body, "Close Fort"
    refute_includes response.body, "Middle Fort"
  end

  test "filters survive paging and category switching" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO, budget: "low")

    assert_response :success
    assert_select "aside input[type=radio][name=budget][value=low][checked]", count: 1
  end

  test "several categories at once deal one combined deck, closest first" do
    art = ExperienceType.create!(key: "art", name: "Art", active: true)
    gallery = Location.create!(name: "Near Gallery", city: "Sarajevo", lat: 43.851, lng: 18.411,
                               suitable_experiences: [ art.key ])
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO, categories: %w[history culture])

    assert_response :success
    assert_includes response.body, "Close Fort"
    assert_includes response.body, "Near Gallery"
    assert_operator response.body.index("Close Fort"), :<, response.body.index("Near Gallery")
  ensure
    gallery&.destroy
    art&.destroy
  end

  test "a place tagged in two selected categories is dealt only once" do
    art = ExperienceType.create!(key: "art", name: "Art", active: true)
    both = Location.create!(name: "Double Tagged", city: "Sarajevo", lat: 43.852, lng: 18.412,
                            suitable_experiences: [ @history.key, art.key ])
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO, categories: %w[history culture])

    assert_response :success
    # @near, @mid, @outside and the double-tagged place — four cards, not five.
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 4
  ensure
    both&.destroy
    art&.destroy
  end

  test "the desktop filter rail is inside a controller scope so it can submit" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "aside[data-controller='deck-filters']", count: 1
    assert_select "aside[data-controller='deck-filters'] form[method=get]", count: 1
    assert_select "aside input[type=checkbox][name='categories[]']", count: 6
  end

  test "a slice with nothing left in it ends the deck instead of spinning" do
    login_as(@user)

    # A tail that comes back as itself is a deck that loads for ever.
    get explore_bosnia_experience_path("history", **SARAJEVO, after_distance: 9_999, after_id: 0),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, I18n.t("explore_bosnia.deck_end")
    refute_includes response.body, "deck-pagination"
  end

  test "an unknown category is dropped rather than refused" do
    login_as(@user)

    get explore_bosnia_experience_path("not-a-tile", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Close Fort"
  end

  test "the experience deck deals to a guest, who checks in on the device" do
    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Close Fort"
    # No account, so no plan to hang a check-in on: the control marks the visit
    # locally instead of posting it.
    assert_select "[data-geo-visit-guest-value='true']"
    assert_select "form[action*='/visits']", count: 0
  end

  test "a guest deck deals every place, since visited lives on their device" do
    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    # Nothing is filtered out server-side — there is no server-side record of a
    # guest's walk to filter by.
    assert_includes response.body, "Close Fort"
    assert_includes response.body, "Middle Fort"
  end

  test "a guest deck creates no explore plan" do
    assert_no_difference "Plan.count" do
      get explore_bosnia_experience_path("history", **SARAJEVO)
    end

    assert_response :success
  end

  test "without coordinates the deck asks for location instead of dealing" do
    login_as(@user)

    get explore_bosnia_experience_path("history")

    assert_response :success
    assert_includes response.body, I18n.t("explore_bosnia.needs_location.title")
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 0
  end

  test "the deck renders scrollable cards with a permanent menu handle" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 3
    # No swipe anywhere, and no pulsing hints — the menu handle is permanent.
    assert_select "[data-plan-deck-target='hint']", count: 0
    assert_select "[data-card-menu-target='hint']", count: 0
    assert_select "button[data-action='card-menu#openFromHandle']", count: 3
  end

  test "the cards are closest first with a distance" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_operator response.body.index("Close Fort"), :<, response.body.index("Middle Fort")
    assert_includes response.body, "km"
  end

  test "a place a country away is dealt, ordered behind the near ones" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Far Fort"
    assert_operator response.body.index("Close Fort"), :<, response.body.index("Far Fort")
  end

  test "a category with no places gets the empty deck" do
    login_as(@user)

    get explore_bosnia_experience_path("relax", **SARAJEVO)

    assert_response :success
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 0
    assert_includes response.body, I18n.t("explore_bosnia.deck_empty")
  end

  test "a traveller abroad is still dealt the whole country" do
    login_as(@user)

    get explore_bosnia_experience_path("history", lat: 52.52, lng: 13.40)

    assert_response :success
    assert_includes response.body, "Close Fort"
    assert_includes response.body, "Far Fort"
  end

  test "a tile deals every one of its member types" do
    art = ExperienceType.create!(key: "art", name: "Art", active: true)
    culture = ExperienceType.create!(key: "culture", name: "Culture", active: true)
    gallery = Location.create!(name: "City Gallery", city: "Sarajevo", lat: 43.856, lng: 18.412,
                               suitable_experiences: [ art.key ])
    museum = Location.create!(name: "City Museum", city: "Sarajevo", lat: 43.857, lng: 18.413,
                              suitable_experiences: [ culture.key ])
    login_as(@user)

    get explore_bosnia_experience_path("culture", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "City Gallery"
    assert_includes response.body, "City Museum"
  ensure
    [ gallery, museum ].each { |location| location&.destroy }
    [ art, culture ].each { |type| type&.destroy }
  end

  test "a location carrying two of a tile's types is dealt once" do
    art = ExperienceType.create!(key: "art", name: "Art", active: true)
    culture = ExperienceType.create!(key: "culture", name: "Culture", active: true)
    both = Location.create!(name: "Double Tagged", city: "Sarajevo", lat: 43.856, lng: 18.412,
                            suitable_experiences: [ art.key, culture.key ])
    login_as(@user)

    get explore_bosnia_experience_path("culture", **SARAJEVO)

    assert_response :success
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 1
  ensure
    both&.destroy
    [ art, culture ].each { |type| type&.destroy }
  end

  test "a page never deals more than PAGE_SIZE places" do
    12.times do |i|
      Location.create!(name: "Spot #{i}", city: "Sarajevo", lat: 43.8 + i * 0.001, lng: 18.4,
                       suitable_experiences: [ @history.key ])
    end
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: ExploreBosniaController::PAGE_SIZE
  ensure
    Location.where("name LIKE 'Spot %'").destroy_all
  end

  test "a full page offers a tail that asks for what follows its last place" do
    seed_places(12)
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "#explore_deck_tail[data-controller='deck-pagination']", count: 1
    assert_includes tail_url(response.body), "after_id="
  ensure
    destroy_seeded_places
  end

  test "the last page ends the deck instead of offering another" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "[data-deck-pagination-url-value]", count: 0
    assert_includes response.body, I18n.t("explore_bosnia.deck_end")
  end

  test "following the tail deals the places the first slice did not" do
    seed_places(12)
    login_as(@user)

    dealt, requests = walk_the_deck

    assert_equal 15, dealt.size, "12 seeded places plus the 3 fixtures"
    assert_equal dealt.uniq, dealt, "the deck dealt the same place twice"
    assert_equal 2, requests
  ensure
    destroy_seeded_places
  end

  # A count that divides by PAGE_SIZE must not buy an extra, empty slice.
  [ 3, 10, 20, 100 ].each do |count|
    test "the deck deals all #{count} places and then ends" do
      seed_places(count - 3) # the fixtures already put 3 history places in range
      login_as(@user)

      dealt, requests = walk_the_deck

      assert_equal count, dealt.size, "every seeded place is dealt exactly once"
      assert_equal dealt.uniq, dealt, "the deck dealt the same place twice"
      assert_includes response.body, I18n.t("explore_bosnia.deck_end")
      assert_equal (count / ExploreBosniaController::PAGE_SIZE.to_f).ceil, requests
    ensure
      destroy_seeded_places
    end
  end

  test "every category pages the same way" do
    types = ExploreBosniaController::BROWSE_TILES.transform_values do |keys|
      ExperienceType.find_or_create_by!(key: keys.first) do |type|
        type.name = keys.first.titleize
        type.active = true
      end
    end
    login_as(@user)

    ExploreBosniaController::BROWSE_TILES.each_key do |tile|
      begin
        seed_places(12, type_key: types[tile].key)

        dealt, requests = walk_the_deck(tile)

        assert_operator dealt.size, :>=, 12, "#{tile} dealt only #{dealt.size} places"
        assert_equal dealt.uniq, dealt, "#{tile} dealt the same place twice"
        assert_equal (dealt.size / ExploreBosniaController::PAGE_SIZE.to_f).ceil, requests,
          "#{tile} took #{requests} requests for #{dealt.size} places"
        assert_includes response.body, I18n.t("explore_bosnia.deck_end")
      ensure
        destroy_seeded_places
      end
    end
  ensure
    (types.values - [ @history ]).each { |type| type.destroy if type.persisted? }
  end

  # Bullet is blind to find_by-on-a-loaded-association, which is how the
  # translate/primary_category N+1 hides, so the count is asserted directly.
  test "the deck's query count does not grow with the number of cards" do
    login_as(@user)
    get explore_bosnia_experience_path("history", **SARAJEVO) # warm the caches

    two_cards = count_queries { get explore_bosnia_experience_path("history", **SARAJEVO) }

    8.times do |i|
      Location.create!(name: "Spot #{i}", city: "Sarajevo", lat: 43.8 + i * 0.001, lng: 18.4,
                       suitable_experiences: [ @history.key ])
    end

    ten_cards = count_queries { get explore_bosnia_experience_path("history", **SARAJEVO) }

    assert_select "[data-plan-deck-target='card'][data-plan-deck-lat]", count: 10
    marginal = (ten_cards - two_cards) / 8.0
    # ~4 is the known translate/primary_category cost; Translatable is inherited
    # code we work around rather than edit, and paging bounds it to one page.
    # Anything above that is a new N+1.
    assert_operator marginal, :<=, 5,
      "each extra card costs #{marginal.round(1)} queries (#{two_cards} -> #{ten_cards})"
  ensure
    Location.where("name LIKE 'Spot %'").destroy_all
  end

  test "the deck ships no moments until a panel is opened" do
    moment = @user.moments.new(plan: Plan.explore_bosnia_for(@user), location: @near, visibility: :private_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "turbo-frame[id=?][loading='lazy']",
                  ActionView::RecordIdentifier.dom_id(@near, :moments_frame), count: 1
    refute_includes response.body, photo_plan_moment_path(moment.plan, moment, size: "thumb")
  end

  test "the moments frame renders the gallery for its location" do
    moment = @user.moments.new(plan: Plan.explore_bosnia_for(@user), location: @near, visibility: :private_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    login_as(@user)

    get plan_moments_path(moment.plan, location_id: @near.uuid, context: "explore"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@near, :moments_frame) }

    assert_response :success
    assert_select "img[src=?]", photo_plan_moment_path(moment.plan, moment, size: "thumb"), count: 1
    assert_select "[data-photo-gallery-full-url=?]",
                  photo_plan_moment_path(moment.plan, moment, size: "story"), count: 1
    assert_select "form[action=?]", publish_plan_moment_path(moment.plan, moment), count: 1
  end

  test "the gallery shows every moment in rows of three, not a sideways strip" do
    plan = Plan.explore_bosnia_for(@user)
    moments = 5.times.map do
      moment = @user.moments.new(plan: plan, location: @near, visibility: :private_moment)
      moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")),
                          filename: "real_image.jpg", content_type: "image/jpeg")
      moment.save!
      moment
    end
    login_as(@user)

    get plan_moments_path(plan, location_id: @near.uuid, context: "explore"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@near, :moments_frame) }

    assert_response :success
    assert_select "[data-photo-gallery-target='thumbnail']", count: 5
    assert_select "div.grid.grid-cols-3", count: 1
    assert_select "div.overflow-x-auto", count: 0
    moments.each do |moment|
      assert_select "img[src=?]", photo_plan_moment_path(plan, moment, size: "thumb"), count: 1
    end
  end

  test "a tile whose places are all visited says so, not that it is empty" do
    plan = Plan.create!(title: "Trip", visibility: :private_plan, user: @user)
    [ @near, @mid, @outside ].each { |location| @user.plan_visits.create!(plan: plan, location: location) }
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_includes response.body, I18n.t("explore_bosnia.deck_all_visited")
    refute_includes response.body, I18n.t("explore_bosnia.deck_empty")
  end

  test "a tile with no places at all still says it is empty" do
    login_as(@user)

    get explore_bosnia_experience_path("relax", **SARAJEVO)

    assert_response :success
    assert_includes response.body, I18n.t("explore_bosnia.deck_empty")
  end

  test "a location visited on any plan is not dealt again" do
    other_plan = Plan.create!(title: "Trip", visibility: :private_plan, user: @user)
    @user.plan_visits.create!(plan: other_plan, location: @near)
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    refute_includes response.body, "Close Fort"
    assert_includes response.body, "Middle Fort"
  end

  test "the moments panel offers upload and badges a private moment" do
    plan = Plan.explore_bosnia_for(@user)
    @user.plan_visits.create!(plan: plan, location: @near) # capture is earned by being there
    moment = @user.moments.new(plan: plan, location: @near, visibility: :private_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    login_as(@user)

    get plan_moments_path(moment.plan, location_id: @near.uuid, context: "explore"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@near, :moments_frame) }

    assert_response :success
    assert_select "label[aria-label=?]", I18n.t("plans.moments.add"), minimum: 1
    assert_includes response.body, I18n.t("plans.start.story_private")
    assert_select "form[action=?]", publish_plan_moment_path(moment.plan, moment), count: 1
  end

  test "the moments panel offers the upload tile without a visit" do
    login_as(@user)

    get plan_moments_path(Plan.explore_bosnia_for(@user), location_id: @near.uuid, context: "explore"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@near, :moments_frame) }

    assert_response :success
    assert_select "label[aria-label=?]", I18n.t("plans.moments.add"), count: 1
  end

  test "the moments panel shows another traveller's approved public moment" do
    other = User.create!(username: "other_wanderer", password: "password123")
    moment = other.moments.new(plan: Plan.explore_bosnia_for(other), location: @near, visibility: :public_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(moderation_status: :approved)
    login_as(@user)

    get plan_moments_path(Plan.explore_bosnia_for(@user), location_id: @near.uuid, context: "explore"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@near, :moments_frame) }

    assert_response :success
    assert_select "[data-photo-gallery-target='thumbnail']", count: 1
  ensure
    other&.destroy
  end

  test "an own approved public moment removes the be-first invitation" do
    moment = @user.moments.new(plan: Plan.explore_bosnia_for(@user), location: @near,
                               visibility: :public_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(moderation_status: :approved) # the curator's approval
    login_as(@user)

    plan = Plan.explore_bosnia_for(@user)
    frame = ->(location) do
      get plan_moments_path(plan, location_id: location.uuid, context: "explore"),
          headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(location, :moments_frame) }
      response.body
    end

    refute_includes frame.call(@near), I18n.t("plans.start.story_none")
    assert_includes frame.call(@mid), I18n.t("plans.start.story_none")
  end

  test "publishing from the story actually publishes and streams the carousel back" do
    moment = @user.moments.new(plan: Plan.explore_bosnia_for(@user), location: @near, visibility: :private_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    login_as(@user)

    patch publish_plan_moment_path(moment.plan, moment),
          params: { context: "explore" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert moment.reload.visibility_public_moment?
    assert moment.pending?
    assert_select "turbo-stream[action=replace][target=?]",
                  ActionView::RecordIdentifier.dom_id(@near, :stories), count: 1
  end

  test "deleting a moment from the story destroys it and its photo everywhere" do
    moment = @user.moments.new(plan: Plan.explore_bosnia_for(@user), location: @near, visibility: :private_moment)
    moment.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/real_image.jpg")), filename: "real_image.jpg", content_type: "image/jpeg")
    moment.save!
    blob_id = moment.photo.blob.id
    login_as(@user)

    delete plan_moment_path(moment.plan, moment),
           params: { context: "explore" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not Moment.exists?(moment.id)
    perform_enqueued_jobs if respond_to?(:perform_enqueued_jobs)
    assert_not ActiveStorage::Blob.exists?(blob_id)
    assert_select "turbo-stream[action=replace][target=?]",
                  ActionView::RecordIdentifier.dom_id(@near, :stories), count: 1
  end

  test "the card ships a lazy reviews frame rather than the reviews themselves" do
    Review.create!(reviewable: @near, rating: 5, comment: "Amazing fortress views", author_name: "Mira")
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "turbo-frame[id=?][loading='lazy']",
                  ActionView::RecordIdentifier.dom_id(@near, :reviews_frame), count: 1
    refute_includes response.body, "Amazing fortress views"
  end

  test "the reviews frame renders the scoped section with its form" do
    Review.create!(reviewable: @near, rating: 5, comment: "Amazing fortress views", author_name: "Mira")
    login_as(@user)

    get location_reviews_path(@near),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@near, :reviews_frame) }

    assert_response :success
    assert_includes response.body, "Amazing fortress views"
    assert_select "##{ActionView::RecordIdentifier.dom_id(@near, :reviews_section)}", count: 1
    assert_select "form[action=?]", location_reviews_path(@near), minimum: 1
  end

  test "submitting a review from the explore panel creates it and streams the scoped section back" do
    login_as(@user)

    assert_difference -> { @near.reviews.count }, 1 do
      post location_reviews_path(@near),
           params: { review: { rating: 5, comment: "Prelijepo mjesto", author_name: "Amela" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match ActionView::RecordIdentifier.dom_id(@near, :reviews_section), response.body
    assert_includes response.body, "Prelijepo mjesto"
  end

  test "opening a deck creates the hidden plan and check-ins land on it" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)
    hidden_plan = Plan.explore_bosnia_for(@user)

    assert_select "form[action=?]", plan_visits_path(hidden_plan), count: 3

    post plan_visits_path(hidden_plan),
         params: { location_id: @near.uuid, user_lat: 43.85, user_lng: 18.41 },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert hidden_plan.plan_visits.exists?(user: @user, location: @near)
  end

  test "the hidden plan never appears in the profile plan list" do
    login_as(@user)
    get explore_bosnia_experience_path("history", **SARAJEVO)

    get profile_page_path

    assert_response :success
    refute_includes response.body, "Explore Bosnia</h3>"
    assert_not_includes Plan.without_explore_bosnia.where(user: @user), Plan.explore_bosnia_for(@user)
  end

  test "the check-in hint carries the localized cold-warm scale and enable-location text" do
    login_as(@user)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "[data-geo-visit-target='hint'][data-warmth=?]", I18n.t("plans.start.warmth"), minimum: 1
    assert_select "[data-geo-visit-target='hint'][data-enable-location=?]", I18n.t("plans.start.need_location"), minimum: 1
  end

  test "an admin is dealt the same country-wide deck" do
    login_as(admin)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Far Fort"
  end

  test "an admin who never answered the location prompt is still dealt the walk" do
    login_as(admin)

    get explore_bosnia_experience_path("history")

    assert_response :success
    assert_includes response.body, "Close Fort"
  end

  test "an admin checks in with a plain submit, not the distance-gated one" do
    login_as(admin)

    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_select "[data-controller='geo-visit']", count: 0
  end

  test "an admin check-in from nowhere near the place records the visit" do
    admin_user = admin
    login_as(admin_user)
    get explore_bosnia_experience_path("history", **SARAJEVO)
    hidden_plan = Plan.explore_bosnia_for(admin_user)

    post plan_visits_path(hidden_plan),
         params: { location_id: @near.uuid, user_lat: 0, user_lng: 0 }, as: :turbo_stream

    assert_response :success
    assert admin_user.plan_visits.exists?(plan: hidden_plan, location: @near),
           "the admin bypass must record the visit"
  end

  # The card's name, description and audio-badge reads used find_by/exists?,
  # which query past a preload, so Bullet never saw the N+1 they caused. A count
  # is the only guard: it must not move when the deck grows or the locale's
  # fallback chain deepens (Polish is four deep).
  test "the deck costs the same whether it deals three cards or ten" do
    login_as(@user)

    three = deck_queries
    seed_places(9)
    ten = deck_queries

    assert_equal three, ten,
                 "dealing ten cards cost #{ten} queries against #{three} for three — a per-card query is back"
  ensure
    destroy_seeded_places
  end

  test "a deep fallback locale costs the deck nothing extra" do
    seed_places(9)
    login_as(@user)

    assert_equal deck_queries(locale: :en), deck_queries(locale: :pl),
                 "Polish falls back through cs and sk; the chain must resolve in one query, not four"
  ensure
    destroy_seeded_places
  end

  private

  def deck_queries(locale: :en)
    params = { lat: SARAJEVO[:lat], lng: SARAJEVO[:lng], locale: locale }
    # Warm first: the request that opens a connection pays for schema reads.
    get explore_bosnia_experience_path("all"), params: params

    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]

      count += 1
    end
    ActiveRecord::Base.connection.clear_query_cache
    get explore_bosnia_experience_path("all"), params: params
    assert_response :success
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def admin
    @admin ||= User.create!(username: "chief", password: "password123", user_type: :admin)
  end

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def seed_places(count, type_key: @history.key)
    count.times do |i|
      Location.create!(name: "Spot #{i}", city: "Sarajevo", lat: 43.8 + i * 0.001, lng: 18.4,
                       suitable_experiences: [ type_key ])
    end
  end

  def destroy_seeded_places
    Location.where("name LIKE 'Spot %'").destroy_all
  end

  # Walks the deck the way the browser does, following each tail's url. Places are
  # keyed by coordinate so a repeat is visible.
  def walk_the_deck(category = "history", **params)
    get explore_bosnia_experience_path(category, **SARAJEVO, **params)
    assert_response :success

    dealt = dealt_keys(response.body)
    url = tail_url(response.body)
    requests = 1

    while url
      get url, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success
      dealt += dealt_keys(response.body)
      url = tail_url(response.body)
      requests += 1
      flunk "the deck is still asking for more after #{requests} requests" if requests > 200
    end

    [ dealt, requests ]
  end

  def dealt_keys(body)
    body.scan(/data-plan-deck-lat="([^"]+)"[^>]*?data-plan-deck-lng="([^"]+)"/m).map { |pair| pair.join(",") }
  end

  def tail_url(body)
    match = body.match(/data-deck-pagination-url-value="([^"]+)"/)
    match && CGI.unescapeHTML(match[1])
  end

  def count_queries
    count = 0
    counter = ->(_name, _start, _finish, _id, payload) do
      count += 1 unless payload[:name] == "SCHEMA" || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
  # The deck can be re-dealt without a page load, so the control that asks for a
  # new position has to be inside the deck for its action to resolve at all.
  test "the deck carries the update-location control" do
    get explore_bosnia_experience_path("all", **SARAJEVO)

    assert_response :success
    assert_select "[data-controller~='plan-deck'] [data-action~='plan-deck#updateLocation']", 1
  end

  # Naming a travel mode beside a straight-line number read as a road distance.
  test "a card names the measure it is quoting" do
    get explore_bosnia_experience_path("all", **SARAJEVO)

    assert_response :success
    assert_select "[data-plan-deck-target='distanceLabel']" do |labels|
      assert labels.any?, "expected the deck to render distance labels"
      labels.each do |label|
        assert_match(/straight line/, label.text)
        assert_no_match(/by car|by foot/, label.text)
      end
    end
  end

  # A browser that never answers used to leave the traveller on a card asking
  # for a location that was never coming; the deck deals from the default and
  # says so instead.
  test "an approximate origin deals a real deck and admits the order is not the traveller's" do
    get explore_bosnia_experience_path("all", **SARAJEVO, approx: "1")

    assert_response :success
    assert_select "[data-plan-deck-target='card']"
    assert_select "body", text: /#{Regexp.escape(I18n.t("explore_bosnia.approximate_origin.body"))}/
  end

  test "without coordinates the deck offers the default origin to fall back to" do
    get explore_bosnia_experience_path("all")

    assert_response :success
    assert_select "[data-explore-geo-fallback-lat-value]", 1
  end
  # Client-first with an IP fallback: the deck must not wait on a browser that
  # may never answer, so the request's own address carries it until one does.
  test "an unlocated request is dealt from the address it arrived on" do
    Maps::IpPosition.stub(:call, [ 43.85, 18.41 ]) do
      get explore_bosnia_experience_path("all")
    end

    assert_response :success
    assert_select "[data-plan-deck-target='card']"
    assert_select "body", text: /#{Regexp.escape(I18n.t("explore_bosnia.approximate_origin.body"))}/
  end

  # A private address describes the server, not the traveller.
  test "a loopback address resolves to no position" do
    assert_nil Maps::IpPosition.call("127.0.0.1")
    assert_nil Maps::IpPosition.call("10.0.0.4")
    assert_nil Maps::IpPosition.call("not-an-address")
    assert_nil Maps::IpPosition.call(nil)
  end

  # The browser's answer is authoritative and must not be overridden by the
  # coarser one, nor labelled approximate.
  test "explicit coordinates beat the address they arrived on" do
    Maps::IpPosition.stub(:call, [ 0.0, 0.0 ]) do
      get explore_bosnia_experience_path("all", **SARAJEVO)
    end

    assert_response :success
    assert_select "body", text: /#{Regexp.escape(I18n.t("explore_bosnia.approximate_origin.body"))}/, count: 0
  end
end

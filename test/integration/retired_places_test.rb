# frozen_string_literal: true

require "test_helper"

# A retired place leaves explore and every walk, and takes nothing new: no
# check-in, no moment, no review. What travellers already hold there survives.
class RetiredPlacesTest < ActionDispatch::IntegrationTest
  setup do
    @traveller = User.create!(username: "retired_walker", email: "retired_walker@example.com",
                              password: "password123").tap(&:confirm)
    @live = Location.create!(name: "Live Spring", city: "Blagaj", lat: 43.2566, lng: 17.9034)
    @retired = Location.create!(name: "Retired Mill", city: "Blagaj", lat: 43.2570, lng: 17.9040)
    @plan = Plan.create!(title: "Blagaj Walk", city_name: "Blagaj", visibility: :public_plan, user: @traveller)
    @plan.add_location(@live, day_number: 1)
    @plan.add_location(@retired, day_number: 1)
    @retired.archive!
  end

  test "a walk no longer holds a retired place" do
    plan = Plan.find(@plan.id)

    assert_equal [ @live.id ], plan.all_location_ids
    assert_equal [ @live ], plan.all_locations
  end

  test "a retired place takes no check-in" do
    sign_in @traveller

    post plan_visits_path(@plan), params: { location_id: @retired.uuid, user_lat: @retired.lat, user_lng: @retired.lng }

    assert_response :not_found
    assert_not @traveller.plan_visits.exists?(location: @retired)
  end

  test "a retired place takes no new moment" do
    sign_in @traveller

    assert_no_difference "Moment.count" do
      post plan_moments_path(@plan), params: {
        moment: { location_id: @retired.uuid, photo: fixture_file_upload("test_image.jpg", "image/jpeg") }
      }
    end
    assert_response :not_found
  end

  test "a retired place and a private plan take no review" do
    sign_in @traveller
    private_plan = Plan.create!(title: "Mine only", city_name: "Blagaj", visibility: :private_plan, user: @traveller)

    assert_no_difference "Review.count" do
      post location_reviews_path(@retired), params: { review: { rating: 5, comment: "Lijepo" } }
      assert_response :not_found
      sign_in @traveller
      post plan_reviews_path(private_plan), params: { review: { rating: 5, comment: "Lijepo" } }
      assert_response :not_found
    end
  end

  test "a device's walk replayed on sign-in skips a retired place" do
    importer = GuestVisitsImporter.new(user: @traveller, payload: [ @live.uuid, @retired.uuid ]).call

    assert_equal 1, importer.imported_count
    assert_equal [ @live.id ], @traveller.plan_visits.pluck(:location_id)
  end
end

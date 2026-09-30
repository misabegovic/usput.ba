# frozen_string_literal: true

require "test_helper"

class AdminExperiencesPlansTest < ActionDispatch::IntegrationTest
  setup do
    @curator = person(:curator)
    @traveller = User.create!(username: "aep_traveller", email: "aep_traveller@example.com", password: "password123")
    @place = Location.create!(name: "Stari most", city: "Mostar", lat: 43.3372, lng: 17.8150)
    @experience = Experience.create!(title: "Mostar walk")
    @curated = Plan.create!(title: "Curated weekend", city_name: "Mostar")
    @shared = Plan.create!(title: "Shared trip", city_name: "Mostar", user: @traveller, visibility: :public_plan)
    @private = Plan.create!(title: "Secret trip", city_name: "Mostar", user: @traveller)
    sign_in @curator
  end

  test "a curator edits an experience and its translations" do
    patch "/admin/resources/experiences/#{@experience.to_param}", params: { experience: { title: "Mostar old town walk", title_de: "Altstadtspaziergang" } }

    @experience.reload
    assert_equal "Mostar old town walk", @experience.title
    assert_equal "Altstadtspaziergang", @experience.title_de
  end

  test "a curator adds a place to an experience at a position" do
    post "/admin/resources/experiences/#{@experience.to_param}/locations",
      params: { fields: { related_id: @place.to_param, position: 2 } }

    assert_equal [ [ @place.id, 2 ] ], @experience.experience_locations.pluck(:location_id, :position)
  end

  test "the plans list holds curated and public plans, never private ones" do
    get "/admin/resources/plans"

    assert_response :success
    assert_includes response.body, "Curated weekend"
    assert_includes response.body, "Shared trip"
    assert_not_includes response.body, "Secret trip"
  end

  test "a private plan is not found even by its link" do
    get "/admin/resources/plans/#{@private.to_param}"

    assert_response :not_found
  end

  test "a curator edits a curated plan but not a traveller's" do
    patch "/admin/resources/plans/#{@curated.to_param}", params: { plan: { title: "Curated long weekend" } }
    assert_equal "Curated long weekend", @curated.reload.title

    patch "/admin/resources/plans/#{@shared.to_param}", params: { plan: { title: "Hijacked" } }
    assert_equal "Shared trip", @shared.reload.title
  end

  test "a curator adds an experience to a curated plan on a given day" do
    post "/admin/resources/plans/#{@curated.to_param}/experiences",
      params: { fields: { related_id: @experience.to_param, day_number: 2, position: 1 } }

    assert_equal [ [ @experience.id, 2, 1 ] ], @curated.plan_experiences.pluck(:experience_id, :day_number, :position)
  end

  test "nothing can be attached to a traveller's plan" do
    post "/admin/resources/plans/#{@shared.to_param}/experiences",
      params: { fields: { related_id: @experience.to_param, day_number: 1, position: 1 } }

    assert_empty @shared.plan_experiences
  end

  test "a curator cannot delete a plan or an experience" do
    delete "/admin/resources/plans/#{@curated.to_param}"
    delete "/admin/resources/experiences/#{@experience.to_param}"

    assert Plan.exists?(@curated.id)
    assert Experience.exists?(@experience.id)
  end

  private

  def person(role)
    User.create!(username: "aep_#{role}", email: "aep_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

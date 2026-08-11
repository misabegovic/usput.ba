# frozen_string_literal: true

require "test_helper"

class PlanTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    @experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 60
    )
    @experience.add_location(@location, position: 1)

    @user = User.create!(
      username: "plantest",
      password: "password123",
      password_confirmation: "password123"
    )

    @valid_params = {
      title: "Test Plan",
      city_name: "Sarajevo"
    }
  end

  teardown do
    @user&.destroy
    @experience&.destroy
    @location&.destroy
  end

  # === Validation tests ===

  test "valid plan is saved" do
    plan = Plan.new(@valid_params)
    assert plan.save
    plan.destroy
  end

  test "title is required" do
    plan = Plan.new(@valid_params.merge(title: nil))
    assert_not plan.valid?
    assert_includes plan.errors[:title], "can't be blank"
  end

  test "end_date must be after start_date" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.yesterday
    ))
    assert_not plan.valid?
    assert plan.errors[:end_date].any?
  end

  test "end_date can equal start_date" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow
    ))
    assert plan.valid?
  end

  # === UUID generation tests ===

  test "uuid is generated on create" do
    plan = Plan.create!(@valid_params)
    assert plan.uuid.present?
    plan.destroy
  end

  # === Visibility tests ===

  test "default visibility is private_plan" do
    plan = Plan.create!(@valid_params)
    assert plan.visibility_private_plan?
    plan.destroy
  end

  test "can set visibility to public_plan" do
    plan = Plan.create!(@valid_params.merge(visibility: :public_plan))
    assert plan.visibility_public_plan?
    plan.destroy
  end

  # === Duration helpers ===

  test "duration_in_days calculates from dates" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days
    ))
    assert_equal 3, plan.duration_in_days
  end

  test "duration_in_days uses calculated duration without dates" do
    plan = Plan.create!(@valid_params)
    plan.plan_experiences.create!(
      experience: @experience,
      day_number: 2,
      position: 1
    )

    assert_equal 2, plan.duration_in_days

    plan.destroy
  end

  test "calculated_duration_days returns days from experiences" do
    plan = Plan.create!(@valid_params)
    plan.plan_experiences.create!(
      experience: @experience,
      day_number: 3,
      position: 1
    )

    assert_equal 3, plan.calculated_duration_days

    plan.destroy
  end

  # === Experience management ===

  test "add_experience adds experience to day" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day
    ))
    plan.add_experience(@experience, day_number: 1)

    assert_includes plan.experiences, @experience

    plan.destroy
  end

  test "add_experience auto-increments position within day" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day
    ))

    exp2 = Experience.create!(title: "Second Experience")

    plan.add_experience(@experience, day_number: 1)
    plan.add_experience(exp2, day_number: 1)

    positions = plan.plan_experiences.where(day_number: 1).pluck(:position)
    assert_equal [ 1, 2 ], positions.sort

    plan.destroy
    exp2.destroy
  end

  test "remove_experience removes from plan" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day
    ))
    plan.add_experience(@experience, day_number: 1)
    plan.remove_experience(@experience)

    assert_not_includes plan.experiences, @experience

    plan.destroy
  end

  test "move_experience_to_day changes day" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days
    ))
    plan.add_experience(@experience, day_number: 1)
    plan.move_experience_to_day(@experience, 2)

    plan_exp = plan.plan_experiences.find_by(experience: @experience)
    assert_equal 2, plan_exp.day_number

    plan.destroy
  end

  test "experiences_for_day returns correct experiences" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day
    ))
    plan.add_experience(@experience, day_number: 1)

    exp2 = Experience.create!(title: "Day 2 Experience")
    plan.add_experience(exp2, day_number: 2, position: 1)

    day1_exps = plan.experiences_for_day(1)
    assert_includes day1_exps, @experience
    assert_not_includes day1_exps, exp2

    plan.destroy
    exp2.destroy
  end

  # === Date helpers ===

  test "date_for_day returns correct date" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2024, 1, 3)
    ))

    assert_equal Date.new(2024, 1, 1), plan.date_for_day(1)
    assert_equal Date.new(2024, 1, 2), plan.date_for_day(2)
    assert_equal Date.new(2024, 1, 3), plan.date_for_day(3)
  end

  test "date_for_day returns nil for invalid day" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2024, 1, 2)
    ))

    assert_nil plan.date_for_day(0)
    assert_nil plan.date_for_day(5)
  end

  test "date_for_day returns nil without start_date" do
    plan = Plan.new(@valid_params)
    assert_nil plan.date_for_day(1)
  end

  test "day_number_for_date returns correct day" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2024, 1, 3)
    ))

    assert_equal 1, plan.day_number_for_date(Date.new(2024, 1, 1))
    assert_equal 2, plan.day_number_for_date(Date.new(2024, 1, 2))
  end

  test "day_number_for_date returns nil for date outside range" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2024, 1, 3)
    ))

    assert_nil plan.day_number_for_date(Date.new(2023, 12, 31))
    assert_nil plan.day_number_for_date(Date.new(2024, 1, 5))
  end

  # === Duration calculations ===

  test "total_duration_for_day sums experience durations" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day
    ))

    exp2 = Experience.create!(title: "Second", estimated_duration: 90)

    plan.add_experience(@experience, day_number: 1)
    plan.add_experience(exp2, day_number: 1)

    assert_equal 150, plan.total_duration_for_day(1) # 60 + 90

    plan.destroy
    exp2.destroy
  end

  test "formatted_duration_for_day formats correctly" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day
    ))
    plan.add_experience(@experience, day_number: 1)

    assert_equal "1h", plan.formatted_duration_for_day(1)

    plan.destroy
  end

  # === Status helpers ===

  test "active? returns true when current date is within range" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.yesterday,
      end_date: Date.tomorrow
    ))
    assert plan.active?
  end

  test "active? returns false when outside range" do
    plan = Plan.new(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days
    ))
    assert_not plan.active?
  end

  test "upcoming? returns true for future plans" do
    plan = Plan.new(@valid_params.merge(start_date: Date.tomorrow))
    assert plan.upcoming?
  end

  test "past? returns true for past plans" do
    plan = Plan.new(@valid_params.merge(end_date: Date.yesterday))
    assert plan.past?
  end

  test "user_plan? returns true with user" do
    plan = Plan.new(@valid_params.merge(user: @user))
    assert plan.user_plan?
  end

  test "user_plan? returns false without user" do
    plan = Plan.new(@valid_params)
    assert_not plan.user_plan?
  end

  # === Cities helper ===

  test "cities returns unique cities from experiences" do
    plan = Plan.create!(@valid_params.merge(
      start_date: Date.tomorrow,
      end_date: Date.tomorrow
    ))
    plan.add_experience(@experience, day_number: 1)

    assert_includes plan.cities, "Sarajevo"

    plan.destroy
  end

  # === Display title ===

  test "display_title returns title by default" do
    plan = Plan.new(@valid_params)
    assert_equal "Test Plan", plan.display_title
  end

  test "display_title returns custom_title from preferences" do
    plan = Plan.new(@valid_params.merge(
      preferences: { "custom_title" => "My Custom Title" }
    ))
    assert_equal "My Custom Title", plan.display_title
  end

  # === Import/Export ===

  test "to_local_storage_format returns expected structure" do
    plan = Plan.create!(@valid_params.merge(
      visibility: :public_plan
    ))

    data = plan.to_local_storage_format

    assert data[:id].present?
    assert data[:uuid].present?
    assert_equal "Sarajevo", data[:city_name]
    assert data[:days].is_a?(Array)
    assert_equal true, data[:saved]
    assert_equal "public_plan", data[:visibility]

    plan.destroy
  end

  test "create_from_local_storage creates plan" do
    data = {
      "id" => "local-123",
      "city_name" => "Sarajevo",
      "duration_days" => 2,
      "days" => [
        {
          "day_number" => 1,
          "experiences" => [
            { "id" => @experience.uuid }
          ]
        }
      ]
    }

    result = Plan.create_from_local_storage(data, user: @user)
    plan = result[:plan]

    assert plan.persisted?
    assert_equal @user, plan.user
    assert_equal "local-123", plan.local_id
    assert plan.plan_experiences.exists?

    plan.destroy
  end

  test "create_from_local_storage returns warnings for missing experiences" do
    data = {
      "id" => "local-456",
      "city_name" => "Sarajevo",
      "days" => [
        {
          "day_number" => 1,
          "experiences" => [
            { "id" => "non-existent-uuid" }
          ]
        }
      ]
    }

    result = Plan.create_from_local_storage(data, user: @user)

    assert result[:warnings].any?
    result[:plan]&.destroy
  end

  test "update_from_local_storage updates plan" do
    plan = Plan.create!(@valid_params.merge(user: @user))

    data = {
      "notes" => "Updated notes",
      "custom_title" => "Updated Title",
      "days" => [
        {
          "day_number" => 1,
          "experiences" => [
            { "id" => @experience.uuid }
          ]
        }
      ]
    }

    result = plan.update_from_local_storage(data)

    assert result[:success]
    plan.reload
    assert_equal "Updated notes", plan.notes
    assert_equal "Updated Title", plan.preferences["custom_title"]

    plan.destroy
  end

  # === Scopes ===

  test "public_plans scope returns only public plans" do
    public_plan = Plan.create!(@valid_params.merge(visibility: :public_plan))
    private_plan = Plan.create!(@valid_params.merge(title: "Private", visibility: :private_plan))

    results = Plan.public_plans
    assert_includes results, public_plan
    assert_not_includes results, private_plan

    public_plan.destroy
    private_plan.destroy
  end

  test "for_city scope filters by city name" do
    sarajevo = Plan.create!(@valid_params)
    mostar = Plan.create!(@valid_params.merge(title: "Mostar Plan", city_name: "Mostar"))

    results = Plan.for_city("Sarajevo")
    assert_includes results, sarajevo
    assert_not_includes results, mostar

    sarajevo.destroy
    mostar.destroy
  end

  test "for_user scope filters by user" do
    user_plan = Plan.create!(@valid_params.merge(user: @user))
    other_plan = Plan.create!(@valid_params.merge(title: "Other"))

    results = Plan.for_user(@user)
    assert_includes results, user_plan
    assert_not_includes results, other_plan

    user_plan.destroy
    other_plan.destroy
  end

  test "upcoming scope filters future plans" do
    upcoming = Plan.create!(@valid_params.merge(start_date: Date.tomorrow))
    past = Plan.create!(@valid_params.merge(
      title: "Past Plan",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday
    ))

    results = Plan.upcoming
    assert_includes results, upcoming
    assert_not_includes results, past

    upcoming.destroy
    past.destroy
  end

  # === Standalone location day-items ===

  test "add_location adds a standalone location to a day" do
    plan = Plan.create!(@valid_params)
    plan.add_location(@location, day_number: 1)

    assert_equal 1, plan.plan_locations.count
    assert_equal [ @location ], plan.locations_for_day(1)
    plan.destroy
  end

  test "remove_location removes a standalone location" do
    plan = Plan.create!(@valid_params)
    plan.add_location(@location, day_number: 1)
    plan.remove_location(@location)

    assert_equal 0, plan.plan_locations.count
    plan.destroy
  end

  test "to_local_storage_format includes day locations" do
    plan = Plan.create!(@valid_params)
    plan.add_location(@location, day_number: 1)

    day1 = plan.to_local_storage_format[:days].first
    assert_equal [ @location.name ], day1[:locations].map { |l| l[:name] }
    assert_equal 1, plan.to_local_storage_format[:total_locations]
    plan.destroy
  end

  test "location round-trips through local storage export and import" do
    plan = Plan.create!(@valid_params.merge(user: @user))
    plan.add_location(@location, day_number: 1)

    data = plan.to_local_storage_format.deep_stringify_keys
    imported = Plan.create_from_local_storage(data, user: @user)[:plan]

    assert_equal [ @location ], imported.locations_for_day(1)
    plan.destroy
    imported.destroy
  end

  test "plan with only a standalone location counts the day" do
    # Mirrors the import path, which creates day-items directly (no day-range guard).
    plan = Plan.create!(@valid_params)
    plan.plan_locations.create!(location: @location, day_number: 2)

    assert_equal 2, plan.calculated_duration_days
    plan.destroy
  end

  test "location_days= sets standalone locations by day (curator path)" do
    plan = Plan.create!(@valid_params)
    plan.location_days = { "1" => [ @location.uuid ], "2" => [ @location.uuid ] }

    assert_equal [ @location ], plan.locations_for_day(1)
    assert_equal [ @location ], plan.locations_for_day(2)
    assert_equal({ "1" => [ @location.uuid ], "2" => [ @location.uuid ] }, plan.location_days)
    plan.destroy
  end

  test "location_days= replaces existing standalone locations" do
    plan = Plan.create!(@valid_params)
    plan.location_days = { "1" => [ @location.uuid ] }
    plan.location_days = { "2" => [ @location.uuid ] }

    assert_empty plan.locations_for_day(1)
    assert_equal [ @location ], plan.locations_for_day(2)
    plan.destroy
  end

  # The sign-in door imports plans from a JSON string, which never passes through
  # strong parameters, so the marker is filtered at the model instead.
  test "a device payload cannot author the explore marker" do
    result = Plan.create_from_local_storage(
      { "city_name" => "Sarajevo", "preferences" => { "budget" => "low", "explore_bosnia" => true } },
      user: @user
    )
    plan = result[:plan]

    assert_not plan.explore_bosnia?
    assert_equal({ "budget" => "low" }, plan.preferences)

    plan.update_from_local_storage({ "preferences" => { "explore_bosnia" => true, "budget" => "high" } })

    assert_not plan.reload.explore_bosnia?
    plan.destroy
  end

  # === Destroying a plan someone else walked ===

  test "deleting a public plan leaves another traveller's visit and moment alive" do
    plan = Plan.create!(@valid_params.merge(user: @user, visibility: :public_plan))
    traveller = create_traveller
    visit = traveller.plan_visits.create!(plan: plan, location: @location)
    moment = build_moment(traveller, plan)

    plan.destroy

    assert PlanVisit.exists?(visit.id), "the visit outlives the plan it was made on"
    assert Moment.exists?(moment.id), "the moment outlives the plan it was made on"
    assert_equal @location.id, visit.reload.location_id
    assert_equal @location.id, moment.reload.location_id
    assert_equal Plan.explore_bosnia_for(traveller).id, visit.plan_id
    assert_equal Plan.explore_bosnia_for(traveller).id, moment.plan_id
  ensure
    traveller&.destroy
  end

  test "a traveller's statistics are unchanged by the plan owner's delete" do
    plan = Plan.create!(@valid_params.merge(user: @user, visibility: :public_plan))
    traveller = create_traveller
    traveller.plan_visits.create!(plan: plan, location: @location)
    before = traveller.travel_profile_data["stats"]

    plan.destroy

    assert_equal before, traveller.reload.travel_profile_data["stats"]
    assert_equal 1, before["totalVisits"]
  ensure
    traveller&.destroy
  end

  # The owner did the walking and took the photos; tidying their plan list must
  # not be what takes them away.
  test "deleting their own plan leaves the owner's visit, moment and photo alive" do
    plan = Plan.create!(@valid_params.merge(user: @user, visibility: :public_plan))
    visit = @user.plan_visits.create!(plan: plan, location: @location)
    moment = build_moment(@user, plan)
    blob_id = moment.photo.blob.id
    stats = @user.travel_profile_data["stats"]

    plan.destroy

    assert PlanVisit.exists?(visit.id)
    assert Moment.exists?(moment.id)
    assert_equal @location.id, visit.reload.location_id
    assert_equal Plan.explore_bosnia_for(@user).id, visit.plan_id
    assert_equal Plan.explore_bosnia_for(@user).id, moment.reload.plan_id
    assert moment.photo.attached?
    assert ActiveStorage::Blob.exists?(blob_id), "the photo is not purged with the plan"
    assert_equal stats, @user.reload.travel_profile_data["stats"]
  end

  test "an owner with no explore plan yet gets one to hold their records" do
    plan = Plan.create!(@valid_params.merge(user: @user))
    @user.plan_visits.create!(plan: plan, location: @location)
    assert_empty @user.plans.reload.select(&:explore_bosnia?)

    plan.destroy

    assert_equal 1, @user.plans.reload.count(&:explore_bosnia?)
    assert_equal [ @location.id ], @user.plan_visits.pluck(:location_id)
  end

  # The explore plan is the destination every other plan re-homes to, so it has
  # nowhere of its own to go.
  test "the explore plan refuses to be destroyed while it holds records" do
    ambient = Plan.explore_bosnia_for(@user)
    @user.plan_visits.create!(plan: ambient, location: @location)

    assert_not ambient.destroy
    assert Plan.exists?(ambient.id)
    assert_equal 1, @user.plan_visits.count
  end

  # The uniqueness index spans traveller, plan and location, so a re-home onto a
  # location the traveller already reached would raise mid-delete.
  test "a visit the traveller already holds elsewhere keeps the earlier arrival" do
    plan = Plan.create!(@valid_params.merge(user: @user, visibility: :public_plan))
    traveller = create_traveller
    ambient = Plan.explore_bosnia_for(traveller)
    later = traveller.plan_visits.create!(plan: ambient, location: @location, created_at: 2.days.ago)
    traveller.plan_visits.create!(plan: plan, location: @location, created_at: 5.days.ago)

    plan.destroy

    assert_equal [ later.id ], traveller.plan_visits.pluck(:id)
    assert_in_delta 5.days.ago, later.reload.created_at, 5.seconds
  ensure
    traveller&.destroy
  end

  test "all_location_count matches the list without loading the places" do
    plan = Plan.create!(title: "Counted", city_name: "Sarajevo", user: @user)
    plan.plan_experiences.create!(experience: @experience, day_number: 1)

    assert_equal plan.all_locations.size, Plan.find(plan.id).all_location_count

    reloaded = Plan.find(plan.id)
    reloaded.all_location_count

    assert_not reloaded.instance_variable_defined?(:@all_locations)

    plan.destroy
  end

  test "all_locations keeps day order, experience position and dedupes" do
    second = Location.create!(name: "Second Place", city: "Mostar", lat: 43.34, lng: 17.81)
    @experience.add_location(second, position: 2)

    plan = Plan.create!(title: "Ordered", city_name: "Sarajevo", user: @user)
    plan.plan_experiences.create!(experience: @experience, day_number: 2)
    # The same place again on an earlier day: one place, dealt on day one.
    plan.plan_locations.create!(location: second, day_number: 1)

    assert_equal [ second.id, @location.id ], plan.all_locations.map(&:id)
    assert_equal 2, plan.all_location_count

    plan.destroy
    second.destroy
  end

  private

  def create_traveller
    User.create!(username: "walker_#{SecureRandom.hex(4)}", password: "password123")
  end

  def build_moment(traveller, plan)
    moment = traveller.moments.build(plan: plan, location: @location)
    moment.photo.attach(
      io: File.open("test/fixtures/files/test_image.jpg"),
      filename: "moment.jpg",
      content_type: "image/jpeg"
    )
    moment.save!
    moment
  end
end

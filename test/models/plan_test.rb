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
    assert_equal [1, 2], positions.sort

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
end

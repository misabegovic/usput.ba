# frozen_string_literal: true

require "test_helper"

class PlanLocationTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(name: "PL Location", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @other_location = Location.create!(name: "PL Location 2", city: "Sarajevo", lat: 43.86, lng: 18.42)
    @plan = Plan.create!(title: "PL Plan", city_name: "Sarajevo", visibility: :private_plan)
  end

  teardown do
    @plan&.destroy
    @location&.destroy
    @other_location&.destroy
  end

  test "valid plan_location is saved" do
    pl = @plan.plan_locations.build(location: @location, day_number: 1)
    assert pl.valid?
    assert pl.save
  end

  test "day_number must be present and positive" do
    pl = @plan.plan_locations.build(location: @location, day_number: 0)
    assert_not pl.valid?
    assert_includes pl.errors[:day_number], "must be greater than 0"
  end

  test "add_location assigns incrementing positions within a day" do
    first = @plan.add_location(@location, day_number: 1)
    second = @plan.add_location(@other_location, day_number: 1)
    assert_equal 1, first.position
    assert_equal 2, second.position
  end

  test "same location cannot be added twice to the same day" do
    @plan.plan_locations.create!(location: @location, day_number: 1)
    dup = @plan.plan_locations.build(location: @location, day_number: 1)
    assert_not dup.valid?
  end

  test "same location can be added to different days" do
    @plan.plan_locations.create!(location: @location, day_number: 1)
    other_day = @plan.plan_locations.build(location: @location, day_number: 2)
    assert other_day.valid?
  end

  test "move_to_day updates the day number" do
    pl = @plan.plan_locations.create!(location: @location, day_number: 1)
    pl.move_to_day(2)
    assert_equal 2, pl.reload.day_number
  end
end

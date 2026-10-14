# frozen_string_literal: true

require "test_helper"

# What experiences, plans and moments copy from their places into the search
# index, and that the copy follows the place when the place changes.
class BrowseReachTest < ActiveSupport::TestCase
  setup do
    @ramp = Location.create!(name: "Ramp Gallery", city: "Tuzla", lat: 44.5384, lng: 18.6734,
                             tags: [ "solana" ], accessibility: { "wheelchair_access" => "full" })
    @stairs = Location.create!(name: "Stair Fort", city: "Tuzla", lat: 44.5400, lng: 18.6800,
                               accessibility: { "wheelchair_access" => "none" })
  end

  test "an experience is accessible only when every place on it is" do
    level = experience_through(@ramp)
    mixed = experience_through(@ramp, @stairs)

    assert row(level).wheelchair_accessible
    assert_not row(mixed).wheelchair_accessible
    assert_includes Browse.by_accessible("true").experiences.pluck(:browsable_id), level.id
  end

  test "an experience with no places is not called accessible" do
    empty = Experience.create!(title: "Nowhere yet", description: "desc")

    assert_not row(empty).wheelchair_accessible
  end

  test "a plan made only of its own stops is placed, described, tagged and found nearby" do
    plan = Plan.create!(title: "Tuzla stops", city_name: "Tuzla", visibility: :public_plan)
    plan.add_location(@ramp, day_number: 1)

    entry = row(plan)
    assert_in_delta @ramp.lat, entry.lat
    assert_includes entry.description, "Ramp Gallery"
    assert entry.wheelchair_accessible
    assert_includes Browse.by_tag("solana").plans.pluck(:browsable_id), plan.id
    assert_includes Browse.nearby(44.5384, 18.6734, radius_km: 2).plans.pluck(:browsable_id), plan.id
  end

  test "a stop added to a plan loses the plan its accessibility" do
    plan = Plan.create!(title: "Tuzla mixed", city_name: "Tuzla", visibility: :public_plan)
    plan.add_location(@ramp, day_number: 1)
    assert row(plan).wheelchair_accessible

    plan.add_location(@stairs, day_number: 1)

    assert_not row(plan).wheelchair_accessible
  end

  test "a place's change reaches its experiences, plans and moments" do
    experience = experience_through(@stairs)
    plan = Plan.create!(title: "Fort day", city_name: "Tuzla", visibility: :public_plan)
    plan.add_location(@stairs, day_number: 1)
    moment = public_moment_at(@stairs, plan)
    assert_not row(moment).wheelchair_accessible

    @stairs.update!(accessibility: { "wheelchair_access" => "partial" })

    assert row(experience).wheelchair_accessible
    assert row(plan).wheelchair_accessible
    assert row(moment).wheelchair_accessible
  end

  test "retiring a place leaves the plan placed by what remains" do
    plan = Plan.create!(title: "Two stops", city_name: "Tuzla", visibility: :public_plan)
    plan.add_location(@stairs, day_number: 1)
    plan.add_location(@ramp, day_number: 1)
    assert_not row(plan).wheelchair_accessible

    @stairs.archive!

    assert row(plan).wheelchair_accessible
    assert_in_delta @ramp.lat, row(plan).lat
  end

  private

  def experience_through(*locations)
    Experience.create!(title: "Through #{locations.map(&:name).join(' and ')}", description: "desc").tap do |experience|
      locations.each_with_index { |location, i| experience.add_location(location, position: i + 1) }
    end
  end

  def public_moment_at(location, plan)
    user = User.create!(username: "reach_#{location.id}", email: "reach_#{location.id}@example.com", password: "password123")
    user.plan_visits.create!(plan: plan, location: location)
    moment = user.moments.build(plan: plan, location: location)
    moment.photo.attach(io: File.open(file_fixture("test_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(visibility: :public_moment)
    moment.update!(moderation_status: :approved)
    moment
  end

  def row(record)
    Browse.find_by!(browsable: record)
  end
end

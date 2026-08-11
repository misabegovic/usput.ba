# frozen_string_literal: true

require "test_helper"

# Every curator show page carries the same action row, top-right of the title:
# View in App · Edit · Delete · Back to list. The pages drifted apart once
# already — experiences and locations had no delete button at all while
# the whole propose/approve chain behind it worked, and plans put its delete in
# a separate block at the bottom of the page. Nothing failed, because no test
# looked at the affordance.
class CuratorShowActionsTest < ActionDispatch::IntegrationTest
  setup do
    @curator = User.create!(username: "actions_curator", password: "password123", user_type: :curator)
    @location = Location.create!(name: "Actions Loc", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @experience = Experience.create!(title: "Actions Exp", description: "d")
    @plan = Plan.create!(title: "Actions Plan", city_name: "Sarajevo", visibility: :private_plan)
    Flipper.enable(:curator_edit_delete)
    login_as(@curator)
  end

  teardown do
    ContentChange.destroy_all
    @plan&.destroy
    @experience&.destroy
    @location&.destroy
    @curator&.destroy
  end

  # path => the DELETE action its button must post to
  def self.deletable_pages
    {
      experiences: ->(t) { [ t.curator_experience_path(t.experience), t.curator_experience_path(t.experience) ] },
      locations: ->(t) { [ t.curator_location_path(t.location), t.curator_location_path(t.location) ] },
      plans: ->(t) { [ t.curator_plan_path(t.plan), t.curator_plan_path(t.plan) ] }
    }
  end

  attr_reader :experience, :location, :plan

  deletable_pages.each do |resource, paths|
    test "#{resource} show offers exactly one delete button, in the header" do
      show_path, delete_path = paths.call(self)

      get show_path

      assert_response :success
      assert_select "form[action=?] input[name='_method'][value='delete']", delete_path, count: 1,
        message: "#{resource} show must have exactly one delete button"
    end

    test "#{resource} show hides delete when the flag is off" do
      Flipper.disable(:curator_edit_delete)
      show_path, = paths.call(self)

      get show_path

      assert_response :success
      assert_select "input[name='_method'][value='delete']", count: 0
    end
  end

  test "reviews show keeps its delete regardless of the flag — moderation, not editing" do
    review = Review.create!(reviewable: @location, rating: 1, comment: "spam", author_name: "x")
    Flipper.disable(:curator_edit_delete)

    get curator_review_path(review)

    assert_response :success
    assert_select "form[action=?] input[name='_method'][value='delete']", curator_review_path(review), count: 1
  ensure
    review&.destroy
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end

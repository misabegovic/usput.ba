# frozen_string_literal: true

require "test_helper"

# The reviews queue in the admin: Jev holds what it is unsure about, a curator
# decides, and any band can be overturned.
class AdminReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @place = Location.create!(name: "Sopotnica", city: "Goražde", lat: 43.5911, lng: 18.8394)
    @author = User.create!(username: "queue_author", email: "queue_author@example.com", password: "password123").tap(&:confirm)
    @held = @place.reviews.create!(rating: 3, comment: "Hmm, held", user: @author, moderation_status: :held, jev_band: "held")
    @fine = @place.reviews.create!(rating: 5, comment: "Already public", user: @author)
  end

  test "the queue opens on the reviews Jev held" do
    sign_in person(:curator)

    get "/admin/resources/reviews"

    assert_response :success
    assert_includes response.body, "Hmm, held"
    assert_not_includes response.body, "Already public"
  end

  test "a curator approves a held review, which then counts and is recorded" do
    sign_in curator = person(:curator)

    run_action "ApproveReview", @held

    assert @held.reload.approved?
    assert_equal 2, @place.reload.reviews_count
    decision = DecisionLog.history(@held).last
    assert_instance_of ReviewApproved, decision
    assert_equal({ record: @held.uuid, by: curator.uuid, decided_by: "curator", overturned: true }, decision.data.symbolize_keys)
  end

  test "a curator rejects an approved review" do
    sign_in person(:curator)

    run_action "RejectReview", @fine

    assert @fine.reload.rejected?
    assert_equal 0, @place.reload.reviews_count
  end

  test "nobody edits a traveller's review in the admin" do
    sign_in person(:admin)

    get "/admin/resources/reviews/#{@held.to_param}/edit"

    assert_not response.successful?
  end

  test "a traveller finds no reviews queue" do
    sign_in @author

    get "/admin/resources/reviews"

    assert_response :not_found
  end

  private

  def run_action(action, review)
    post "/admin/resources/reviews/actions/Avo::Actions::#{action}",
      params: { fields: { avo_resource_ids: review.to_param, avo_selected_all: "false" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def person(role)
    User.create!(username: "queue_#{role}", email: "queue_#{role}@example.com",
                 password: "password123", user_type: role).tap(&:confirm)
  end
end

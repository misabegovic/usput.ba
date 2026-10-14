# frozen_string_literal: true

require "test_helper"

# A review from submission to a reader's page, under Jev's three bands.
class ReviewModerationFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ENFORCE = { mode: "enforce", approve_below: 0.35, reject_above: 0.85, model: "jev-latest" }.freeze

  setup do
    @place = Location.create!(name: "Vrelo Bune", city: "Blagaj", lat: 43.2566, lng: 17.9034)
    @author = person(:basic, "author")
    @stranger = person(:basic, "stranger")
  end

  test "a guest is asked to sign in before reviewing" do
    assert_no_difference "Review.count" do
      post location_reviews_path(@place), params: { review: { rating: 5, comment: "Divno" } }
    end

    assert_redirected_to new_user_session_path
  end

  test "a review belongs to its author, is judged in a job, and the request does not wait" do
    sign_in @author

    assert_enqueued_with(job: ReviewJudgmentJob) do
      post location_reviews_path(@place), params: { review: { rating: 5, comment: "Divno", author_name: "Someone else" } }
    end

    review = Review.last
    assert_equal @author, review.user
    assert_nil review.author_name, "the name comes from the account, not the form"
    assert_equal [ ReviewSubmitted ], DecisionLog.history(review).map(&:class)
  end

  test "in observe mode a review is public at once, as before" do
    sign_in @author

    post location_reviews_path(@place), params: { review: { rating: 5, comment: "Divno" } }

    assert Review.last.approved?
  end

  test "in enforce mode a review waits until Jev answers" do
    sign_in @author

    ReviewModeration.stub(:config, ENFORCE) do
      post location_reviews_path(@place), params: { review: { rating: 2, comment: "Hladno i gužva" } }
    end

    assert Review.last.pending?
  end

  test "a stranger never sees a held review, its author always does" do
    held = @place.reviews.create!(rating: 1, comment: "Held for a curator", user: @author, moderation_status: :held)

    get location_path(@place)
    assert_not_includes response.body, held.comment

    sign_in @stranger
    get location_path(@place)
    assert_not_includes response.body, held.comment
    sign_out @stranger

    sign_in @author
    get location_path(@place)
    assert_includes response.body, held.comment
    assert_includes response.body, I18n.t("reviews.status.held", locale: :en)
  end

  test "only approved reviews move a place's rating" do
    @place.reviews.create!(rating: 5, comment: "Public", user: @stranger)
    @place.reviews.create!(rating: 1, comment: "Held", user: @author, moderation_status: :held)

    @place.reload
    assert_equal 5.0, @place.average_rating.to_f
    assert_equal 1, @place.reviews_count
  end

  test "a guest sees a sign-in link instead of the review form" do
    get location_path(@place)

    assert_includes response.body, I18n.t("reviews.sign_in_to_review", locale: :en)
  end

  private

  def person(role, name)
    User.create!(username: "flow_#{name}", email: "flow_#{name}@example.com",
                 password: "password123", user_type: role).tap(&:confirm)
  end
end

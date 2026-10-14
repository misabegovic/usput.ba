# frozen_string_literal: true

require "test_helper"

class ReviewJudgmentJobTest < ActiveJob::TestCase
  test "reads the review with Jev and records the reading" do
    place = Location.create!(name: "Jajce", city: "Jajce", lat: 44.3415, lng: 17.2706)
    review = place.reviews.create!(rating: 5, comment: "Vodopad u gradu!")
    reading = ReviewModeration::Result.new(band: :approved, answers: { "abusive" => 0.01, "spam" => 0.02 },
                                           model: "jev-1.13.0", skip: nil)

    ReviewModeration.stub(:screen, reading) { ReviewJudgmentJob.perform_now(review.id) }

    assert_equal "approved", review.reload.jev_band
    assert_equal "jev-1.13.0", review.jev_model
  end

  test "a review deleted before its turn is skipped" do
    assert_nothing_raised { ReviewJudgmentJob.perform_now(0) }
  end
end

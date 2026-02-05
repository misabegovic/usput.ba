require "test_helper"

class ReviewModerationTest < ActiveSupport::TestCase
  test "default moderation_status is unreviewed" do
    review = Review.new(
      reviewable: locations(:one),
      rating: 5,
      comment: "Great place!"
    )
    review.save!

    assert_equal "unreviewed", review.moderation_status
    assert review.unreviewed?
  end

  test "can set moderation_status to approved" do
    review = reviews(:one)
    review.update!(moderation_status: :approved)

    assert_equal "approved", review.moderation_status
    assert review.approved?
  end

  test "can set moderation_status to flagged" do
    review = reviews(:one)
    review.update!(moderation_status: :flagged)

    assert_equal "flagged", review.moderation_status
    assert review.flagged?
  end

  test "can set moderation_status to removed" do
    review = reviews(:one)
    review.update!(moderation_status: :removed)

    assert_equal "removed", review.moderation_status
    assert review.removed?
  end

  test "needs_moderation scope returns unreviewed and flagged reviews" do
    review1 = reviews(:one)
    review2 = reviews(:two)
    review3 = Review.create!(reviewable: locations(:one), rating: 5, moderation_status: :unreviewed)
    review4 = Review.create!(reviewable: locations(:one), rating: 4, moderation_status: :flagged)
    review5 = Review.create!(reviewable: locations(:one), rating: 3, moderation_status: :approved)
    review6 = Review.create!(reviewable: locations(:one), rating: 2, moderation_status: :removed)

    # Set test data to known states
    review1.update!(moderation_status: :unreviewed)
    review2.update!(moderation_status: :flagged)

    needs_moderation = Review.needs_moderation

    assert_includes needs_moderation, review1
    assert_includes needs_moderation, review2
    assert_includes needs_moderation, review3
    assert_includes needs_moderation, review4
    assert_not_includes needs_moderation, review5
    assert_not_includes needs_moderation, review6
  end

  test "moderated scope returns approved and removed reviews" do
    review1 = reviews(:one)
    review2 = reviews(:two)
    review3 = Review.create!(reviewable: locations(:one), rating: 5, moderation_status: :unreviewed)
    review4 = Review.create!(reviewable: locations(:one), rating: 4, moderation_status: :flagged)
    review5 = Review.create!(reviewable: locations(:one), rating: 3, moderation_status: :approved)
    review6 = Review.create!(reviewable: locations(:one), rating: 2, moderation_status: :removed)

    # Set test data to known states
    review1.update!(moderation_status: :approved)
    review2.update!(moderation_status: :removed)

    moderated = Review.moderated

    assert_includes moderated, review1
    assert_includes moderated, review2
    assert_includes moderated, review5
    assert_includes moderated, review6
    assert_not_includes moderated, review3
    assert_not_includes moderated, review4
  end

  test "flagged_by? returns true if user flagged the review" do
    review = reviews(:one)
    user = users(:one)

    ReviewFlag.create!(review: review, user: user, reason: "spam")

    assert review.flagged_by?(user)
  end

  test "flagged_by? returns false if user has not flagged the review" do
    review = reviews(:one)
    user = users(:one)

    assert_not review.flagged_by?(user)
  end

  test "flagged_by? returns false if user is nil" do
    review = reviews(:one)

    assert_not review.flagged_by?(nil)
  end

  test "flag_count returns number of flags" do
    review = reviews(:one)
    user1 = users(:one)
    user2 = users(:two)

    assert_equal 0, review.flag_count

    ReviewFlag.create!(review: review, user: user1, reason: "spam")
    assert_equal 1, review.flag_count

    ReviewFlag.create!(review: review, user: user2, reason: "inappropriate")
    assert_equal 2, review.flag_count
  end

  test "has_many review_flags association" do
    review = reviews(:one)
    user = users(:one)

    flag = ReviewFlag.create!(review: review, user: user, reason: "spam")

    assert_includes review.review_flags, flag
  end

  test "dependent destroy on review_flags" do
    review = reviews(:one)
    user = users(:one)

    flag = ReviewFlag.create!(review: review, user: user, reason: "spam")
    flag_id = flag.id

    review.destroy

    assert_nil ReviewFlag.find_by(id: flag_id)
  end
end

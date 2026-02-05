require "test_helper"

class ReviewFlagTest < ActiveSupport::TestCase
  test "valid creation with spam reason" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.create!(review: review, user: user, reason: "spam")

    assert flag.persisted?
    assert_equal "spam", flag.reason
  end

  test "valid creation with inappropriate reason" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.create!(review: review, user: user, reason: "inappropriate")

    assert_equal "inappropriate", flag.reason
  end

  test "valid creation with inaccurate reason" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.create!(review: review, user: user, reason: "inaccurate")

    assert_equal "inaccurate", flag.reason
  end

  test "valid creation with other reason" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.create!(review: review, user: user, reason: "other")

    assert_equal "other", flag.reason
  end

  test "validates uniqueness of user per review" do
    review = reviews(:one)
    user = users(:one)

    ReviewFlag.create!(review: review, user: user, reason: "spam")

    duplicate_flag = ReviewFlag.new(review: review, user: user, reason: "inappropriate")
    assert_not duplicate_flag.valid?
    assert_includes duplicate_flag.errors[:user_id], "has already flagged this review"
  end

  test "different users can flag the same review" do
    review = reviews(:one)
    user1 = users(:one)
    user2 = users(:two)

    flag1 = ReviewFlag.create!(review: review, user: user1, reason: "spam")
    flag2 = ReviewFlag.create!(review: review, user: user2, reason: "inappropriate")

    assert flag1.persisted?
    assert flag2.persisted?
  end

  test "after create updates review moderation_status to flagged" do
    review = reviews(:one)
    review.update!(moderation_status: :unreviewed)
    user = users(:one)

    assert_equal "unreviewed", review.moderation_status

    ReviewFlag.create!(review: review, user: user, reason: "spam")
    review.reload

    assert_equal "flagged", review.moderation_status
  end

  test "does not update moderation_status if review is already approved" do
    review = reviews(:one)
    review.update!(moderation_status: :approved)
    user = users(:one)

    ReviewFlag.create!(review: review, user: user, reason: "spam")
    review.reload

    assert_equal "approved", review.moderation_status
  end

  test "invalid reason is rejected" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.new(review: review, user: user, reason: "invalid_reason")

    assert_not flag.valid?
    assert_includes flag.errors[:reason], "is not included in the list"
  end

  test "requires reason" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.new(review: review, user: user, reason: nil)

    assert_not flag.valid?
    assert_includes flag.errors[:reason], "can't be blank"
  end

  test "can have optional notes" do
    review = reviews(:one)
    user = users(:one)
    flag = ReviewFlag.create!(
      review: review,
      user: user,
      reason: "spam",
      notes: "This is clearly automated spam"
    )

    assert_equal "This is clearly automated spam", flag.notes
  end
end

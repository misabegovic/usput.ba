# frozen_string_literal: true

require "test_helper"

class CuratorReviewTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(
      username: "test_curator_review",
      password: "password123",
      user_type: :curator
    )
    @proposer = User.create!(
      username: "proposer",
      password: "password123",
      user_type: :curator
    )
    @content_change = ContentChange.create!(
      user: @proposer,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Test Location" }
    )
  end

  teardown do
    CuratorReview.destroy_all
    @content_change&.destroy
    @curator&.destroy
    @proposer&.destroy
  end

  test "valid curator review" do
    review = CuratorReview.new(
      content_change: @content_change,
      user: @curator,
      comment: "This looks good, I recommend approval",
      recommendation: :recommend_approve
    )
    assert review.valid?
  end

  test "requires comment" do
    review = CuratorReview.new(
      content_change: @content_change,
      user: @curator,
      recommendation: :recommend_approve
    )
    assert_not review.valid?
    assert_includes review.errors[:comment], "can't be blank"
  end

  test "comment must be at least 10 characters" do
    review = CuratorReview.new(
      content_change: @content_change,
      user: @curator,
      comment: "Short",
      recommendation: :neutral
    )
    assert_not review.valid?
    assert review.errors[:comment].any? { |e| e.include?("too short") }
  end

  test "comment must be at most 2000 characters" do
    review = CuratorReview.new(
      content_change: @content_change,
      user: @curator,
      comment: "a" * 2001,
      recommendation: :neutral
    )
    assert_not review.valid?
    assert review.errors[:comment].any? { |e| e.include?("too long") }
  end

  test "requires content_change" do
    review = CuratorReview.new(
      user: @curator,
      comment: "This is a valid comment length",
      recommendation: :neutral
    )
    assert_not review.valid?
    assert_includes review.errors[:content_change], "must exist"
  end

  test "requires user" do
    review = CuratorReview.new(
      content_change: @content_change,
      comment: "This is a valid comment length",
      recommendation: :neutral
    )
    assert_not review.valid?
    assert_includes review.errors[:user], "must exist"
  end

  test "default recommendation is neutral" do
    review = CuratorReview.new(
      content_change: @content_change,
      user: @curator,
      comment: "Just observing this proposal"
    )
    review.save!
    assert review.neutral?
  end

  test "recommend_approve scope" do
    CuratorReview.create!(
      content_change: @content_change,
      user: @curator,
      comment: "I recommend approval",
      recommendation: :recommend_approve
    )

    assert_equal 1, CuratorReview.recommend_approve.count
    assert_equal 0, CuratorReview.recommend_reject.count
  end

  test "recommend_reject scope" do
    CuratorReview.create!(
      content_change: @content_change,
      user: @curator,
      comment: "I recommend rejection",
      recommendation: :recommend_reject
    )

    assert_equal 0, CuratorReview.recommend_approve.count
    assert_equal 1, CuratorReview.recommend_reject.count
  end

  test "sanitizes comment to prevent XSS" do
    review = CuratorReview.new(
      content_change: @content_change,
      user: @curator,
      comment: "<script>alert('xss')</script>This is safe <b>bold</b> text",
      recommendation: :neutral
    )
    review.save!

    # Script tags should be stripped
    assert_not_includes review.comment, "<script>"
    # Safe tags should be kept
    assert_includes review.comment, "<b>bold</b>"
  end

  test "recent scope orders by created_at desc" do
    reviewer2 = User.create!(username: "reviewer2", password: "password123", user_type: :curator)

    first_review = CuratorReview.create!(
      content_change: @content_change,
      user: @curator,
      comment: "First review comment",
      recommendation: :neutral,
      created_at: 2.days.ago
    )
    second_review = CuratorReview.create!(
      content_change: @content_change,
      user: reviewer2,
      comment: "Second review comment",
      recommendation: :recommend_approve,
      created_at: 1.day.ago
    )

    recent = CuratorReview.recent
    assert_equal second_review, recent.first
    assert_equal first_review, recent.last

    reviewer2.destroy
  end
end

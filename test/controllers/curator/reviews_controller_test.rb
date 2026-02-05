# frozen_string_literal: true

require "test_helper"

module Curator
  class ReviewsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @curator = users(:one)
      @location = locations(:one)
      @review = Review.create!(
        reviewable: @location,
        rating: 4,
        comment: "Great place!",
        author_name: "Test User"
      )
      login_as @curator
    end

    def login_as(user)
      post login_path, params: {
        username: user.username,
        password: "password123"
      }
    end

    test "should get index" do
      get curator_reviews_path
      assert_response :success
    end

    test "should filter by moderation_status" do
      @review.update!(moderation_status: :flagged)
      get curator_reviews_path(moderation_status: :flagged)
      assert_response :success
    end

    test "should show review" do
      get curator_review_path(@review)
      assert_response :success
    end

    test "should flag review" do
      assert_difference "ReviewFlag.count", 1 do
        post flag_curator_review_path(@review), params: {
          reason: "spam",
          notes: "This is spam content"
        }
      end
      assert_redirected_to curator_reviews_path
      assert_equal "Recenzija prijavljena.", flash[:notice]
    end

    test "should record activity when flagging" do
      assert_difference "CuratorActivity.count", 1 do
        post flag_curator_review_path(@review), params: {
          reason: "spam",
          notes: "This is spam"
        }
      end
      activity = CuratorActivity.last
      assert_equal "review_flagged", activity.action
      assert_equal @review, activity.recordable
    end

    test "should prevent duplicate flags from same user" do
      ReviewFlag.create!(
        review: @review,
        user: @curator,
        reason: "spam"
      )

      assert_no_difference "ReviewFlag.count" do
        post flag_curator_review_path(@review), params: {
          reason: "inappropriate"
        }
      end
      assert_redirected_to curator_reviews_path
      assert_equal "Već ste prijavili ovu recenziju.", flash[:alert]
    end

    test "should allow different users to flag same review" do
      another_curator = users(:two)
      ReviewFlag.create!(
        review: @review,
        user: @curator,
        reason: "spam"
      )

      login_as another_curator
      assert_difference "ReviewFlag.count", 1 do
        post flag_curator_review_path(@review), params: {
          reason: "inappropriate"
        }
      end
      assert_redirected_to curator_reviews_path
    end

    test "flagging should update review moderation_status to flagged" do
      assert_changes -> { @review.reload.moderation_status }, from: "unreviewed", to: "flagged" do
        post flag_curator_review_path(@review), params: {
          reason: "spam"
        }
      end
    end

    test "should submit delete proposal" do
      assert_difference "ContentChange.count", 1 do
        delete curator_review_path(@review)
      end
      assert_redirected_to curator_reviews_path
    end
  end
end

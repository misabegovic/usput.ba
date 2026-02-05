# frozen_string_literal: true

require "test_helper"

module Curator
  module Admin
    class ReviewsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @admin = users(:admin)
        @curator = users(:one)
        @location = locations(:one)
        @review = Review.create!(
          reviewable: @location,
          rating: 4,
          comment: "Great place!",
          author_name: "Test User"
        )
        login_as @admin
      end

      def login_as(user)
        post login_path, params: {
          username: user.username,
          password: "password123"
        }
      end

      test "should redirect non-admin users" do
        login_as @curator
        get curator_admin_reviews_path
        assert_redirected_to curator_root_path
      end

      test "should get index" do
        get curator_admin_reviews_path
        assert_response :success
        assert_select "h1", text: "Moderacija recenzija"
      end

      test "should show stats on index" do
        get curator_admin_reviews_path
        assert_response :success
        # Check that stats are displayed (looking for the stat value)
        assert_select "dd", minimum: 1
      end

      test "should filter by moderation_status" do
        @review.update!(moderation_status: :flagged)
        get curator_admin_reviews_path(moderation_status: :flagged)
        assert_response :success
      end

      test "should filter by type" do
        get curator_admin_reviews_path(type: "Location")
        assert_response :success
      end

      test "should search reviews" do
        get curator_admin_reviews_path(search: "Great")
        assert_response :success
      end

      test "should show review" do
        get curator_admin_review_path(@review)
        assert_response :success
        assert_select "h1", text: "Recenzija"
      end

      test "should approve review" do
        assert_changes -> { @review.reload.moderation_status }, from: "unreviewed", to: "approved" do
          post approve_curator_admin_review_path(@review)
        end
        assert_redirected_to curator_admin_reviews_path
        assert_equal "Recenzija odobrena.", flash[:notice]
      end

      test "should record activity when approving" do
        assert_difference "CuratorActivity.count", 1 do
          post approve_curator_admin_review_path(@review)
        end
        activity = CuratorActivity.last
        assert_equal "approve_review", activity.action
        assert_equal @review, activity.recordable
      end

      test "should remove review" do
        assert_changes -> { @review.reload.moderation_status }, from: "unreviewed", to: "removed" do
          post remove_curator_admin_review_path(@review)
        end
        assert_redirected_to curator_admin_reviews_path
        assert_equal "Recenzija uklonjena.", flash[:notice]
      end

      test "should record activity when removing" do
        assert_difference "CuratorActivity.count", 1 do
          post remove_curator_admin_review_path(@review)
        end
        activity = CuratorActivity.last
        assert_equal "remove_review", activity.action
        assert_equal @review, activity.recordable
      end
    end
  end
end

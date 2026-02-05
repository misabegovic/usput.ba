# frozen_string_literal: true

module Curator
  module Admin
    # Reviews moderation controller for admin users.
    # Allows admins to approve or remove reviews based on flags and moderation status.
    class ReviewsController < BaseController
      before_action :set_review, only: [ :show, :approve, :remove ]

      def index
        @reviews = Review.includes(:reviewable, :user, :review_flags).order(created_at: :desc)
        @reviews = @reviews.where(moderation_status: params[:moderation_status]) if params[:moderation_status].present?
        @reviews = @reviews.where(reviewable_type: params[:type]) if params[:type].present?
        @reviews = @reviews.by_rating(params[:rating]) if params[:rating].present?

        if params[:search].present?
          @reviews = @reviews.where("comment ILIKE ? OR author_name ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
        end

        @reviews = @reviews.page(params[:page]).per(20)

        @stats = {
          total: Review.count,
          unreviewed: Review.unreviewed.count,
          flagged: Review.flagged.count,
          approved: Review.where(moderation_status: :approved).count,
          removed: Review.removed.count
        }
      end

      def show
      end

      def approve
        if @review.update(moderation_status: :approved)
          record_activity("approve_review", recordable: @review)
          redirect_to curator_admin_reviews_path, notice: "Recenzija odobrena."
        else
          redirect_to curator_admin_review_path(@review), alert: "Greška pri odobravanju."
        end
      end

      def remove
        if @review.update(moderation_status: :removed)
          record_activity("remove_review", recordable: @review)
          redirect_to curator_admin_reviews_path, notice: "Recenzija uklonjena."
        else
          redirect_to curator_admin_review_path(@review), alert: "Greška pri uklanjanju."
        end
      end

      private

      def set_review
        @review = Review.find_by!(uuid: params[:id])
      end
    end
  end
end

module Curator
  class ReviewsController < BaseController
    before_action :set_review, only: [ :show, :destroy ]

    def index
      @reviews = Review.includes(:reviewable, :user).order(created_at: :desc)
      @reviews = @reviews.by_rating(params[:rating]) if params[:rating].present?
      @reviews = @reviews.where(reviewable_type: params[:type]) if params[:type].present?

      if params[:search].present?
        @reviews = @reviews.where("comment ILIKE ? OR author_name ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      @stats = {
        total: Review.count,
        average_rating: Review.average(:rating)&.round(2) || 0,
        with_comments: Review.with_comments.count,
        by_type: Review.group(:reviewable_type).count,
        by_rating: Review.group(:rating).count
      }
    end

    def show
    end

    def destroy
      reviewable = @review.reviewable
      @review.destroy
      redirect_to curator_reviews_path, notice: t("curator.reviews.deleted")
    end

    private

    def set_review
      @review = Review.find(params[:id])
    end
  end
end

module Curator
  class ReviewsController < BaseController
    before_action :set_review, only: [ :show, :destroy ]
    before_action :require_admin, only: :destroy
    rescue_from ActiveRecord::RecordNotFound, with: :review_not_found

    def index
      @reviews = Review.includes(:reviewable, :user).order(created_at: :desc)
      @reviews = @reviews.by_rating(params[:rating]) if params[:rating].present?
      @reviews = @reviews.where(reviewable_type: params[:type]) if params[:type].present?

      if params[:search].present?
        @reviews = @reviews.where("comment ILIKE ? OR author_name ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      @reviews = @reviews.page(params[:page]).per(20)

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
      @review.destroy!
      redirect_to curator_reviews_path, notice: t("curator.reviews.removed"), status: :see_other
    end

    private

    def set_review
      # Review includes Identifiable, so to_param — and therefore every generated
      # path — is the uuid. Review.find looks up by id and never resolves it.
      @review = Review.find_by_public_id!(params[:id])
    end

    def review_not_found
      redirect_to curator_reviews_path, alert: "Review not found. It may have been deleted."
    end
  end
end

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

      @reviews = @reviews.page(params[:page]).per(20)

      @stats = {
        total: Review.count,
        average_rating: Review.average(:rating)&.round(2) || 0,
        with_comments: Review.with_comments.count,
        by_type: Review.group(:reviewable_type).count,
        by_rating: Review.group(:rating).count
      }

      # Show pending proposals for this curator
      @pending_proposals = current_user.content_changes
        .where(changeable_type: "Review")
        .pending
        .order(created_at: :desc)
    end

    def show
    end

    def destroy
      # Use find_or_create to ensure only one pending proposal per resource
      proposal = ContentChange.find_or_create_for_delete(
        changeable: @review,
        user: current_user,
        original_data: @review.attributes.slice(*editable_attributes)
      )

      if proposal.persisted?
        redirect_to curator_reviews_path, notice: t("curator.proposals.delete_submitted_for_review")
      else
        redirect_to curator_reviews_path, alert: t("curator.proposals.failed_to_submit")
      end
    end

    private

    def set_review
      @review = Review.find(params[:id])
    end

    def editable_attributes
      %w[rating comment author_name reviewable_type reviewable_id user_id]
    end
  end
end

class ReviewsController < ApplicationController
  # A review has an author, so the author can always see it, whatever Jev
  # decided (decided 2026-09-30: reviews require signing in).
  before_action :require_login, only: :create
  before_action :set_reviewable

  def index
    @page = (params[:page] || 1).to_i
    @per_page = 5
    visible = @reviewable.reviews.visible_to(current_user)
    @reviews = visible.recent.offset((@page - 1) * @per_page).limit(@per_page)
    @total_reviews = visible.count
    @has_more = (@page * @per_page) < @total_reviews

    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render :index, layout: false
        else
          redirect_to polymorphic_path(@reviewable)
        end
      end
      format.turbo_stream
    end
  end

  def create
    @review = @reviewable.reviews.build(review_params.merge(user: current_user,
                                                            moderation_status: ReviewModeration.initial_status))
    @saved = @review.save
    if @saved
      DecisionLog.publish(ReviewSubmitted, @review, by: current_user)
      ReviewJudgmentJob.perform_later(@review.id)
    end

    respond_to do |format|
      if @saved
        format.html do
          redirect_back fallback_location: root_path,
                        notice: t(@review.pending? ? "flash.review.created_pending" : "flash.review.created")
        end
      else
        format.html { redirect_back fallback_location: root_path, alert: @review.errors.full_messages.join(", ") }
      end
      format.turbo_stream
    end
  end

  private

  def set_reviewable
    @reviewable = if params[:location_id]
      Location.find_by_public_id!(params[:location_id])
    elsif params[:experience_id]
      Experience.find_by_public_id!(params[:experience_id])
    elsif params[:plan_id]
      Plan.find_by_public_id!(params[:plan_id])
    end

    unless @reviewable
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Resource not found" }
        format.turbo_stream { head :not_found }
      end
    end
  end

  def review_params
    params.require(:review).permit(:rating, :comment)
  end
end

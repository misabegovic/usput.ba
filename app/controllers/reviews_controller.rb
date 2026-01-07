class ReviewsController < ApplicationController
  before_action :set_reviewable

  def index
    @page = (params[:page] || 1).to_i
    @per_page = 5
    @reviews = @reviewable.reviews.recent.offset((@page - 1) * @per_page).limit(@per_page)
    @total_reviews = @reviewable.reviews_count
    @has_more = (@page * @per_page) < @total_reviews

    respond_to do |format|
      format.html { redirect_to polymorphic_path(@reviewable) }
      format.turbo_stream
    end
  end

  def create
    @review = @reviewable.reviews.build(review_params)

    respond_to do |format|
      if @review.save
        format.html { redirect_back fallback_location: root_path, notice: t("flash.review.created") }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("reviews-section", partial: "reviews/reviews_section", locals: { reviewable: @reviewable }) }
      else
        format.html { redirect_back fallback_location: root_path, alert: @review.errors.full_messages.join(", ") }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("review-form", partial: "reviews/form", locals: { reviewable: @reviewable, review: @review }) }
      end
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
    params.require(:review).permit(:rating, :comment, :author_name, :author_email)
  end
end

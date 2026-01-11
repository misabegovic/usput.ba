class ExperiencesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_explore

  def show
    @experience = Experience.includes(:locations, :reviews).find_by_public_id!(params[:id])
    @reviews = @experience.reviews.recent.limit(10)
    @review = Review.new
    @nearby_experiences = @experience.nearby_featured(limit: 3)

    # Public plans that include this experience
    plans_scope = Plan.public_plans
                      .joins(:experiences)
                      .where(experiences: { id: @experience.id })
                      .distinct
    @related_plans = plans_scope.order(average_rating: :desc).limit(3)
    @total_plans_count = plans_scope.count
  end

  private

  def redirect_to_explore
    redirect_to explore_path, alert: I18n.t("experiences.not_found", default: "Experience not found. Explore other experiences.")
  end
end

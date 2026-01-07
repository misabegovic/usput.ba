class LocationsController < ApplicationController
  def show
    @location = Location.includes(:reviews).find_by_public_id!(params[:id])
    @reviews = @location.reviews.recent.limit(10)
    @review = Review.new
    @nearby_locations = @location.nearby_featured(limit: 3)

    # Experiences that include this location
    experiences_scope = @location.experiences
                                 .includes(:experience_category)
                                 .with_attached_cover_photo
                                 .order(average_rating: :desc)
    @related_experiences = experiences_scope.limit(3)
    @total_experiences_count = @location.experiences.count

    # Public plans that include this location (through experiences)
    plans_scope = Plan.public_plans
                      .joins(experiences: :locations)
                      .where(locations: { id: @location.id })
                      .distinct
    @related_plans = plans_scope.order(average_rating: :desc).limit(3)
    @total_plans_count = plans_scope.count
  end

  def audio_tour
    @location = Location.find_by_public_id!(params[:id])
  end
end

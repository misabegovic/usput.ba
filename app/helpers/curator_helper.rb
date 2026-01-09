# frozen_string_literal: true

module CuratorHelper
  # Generate a link path for a curator activity's recordable
  def activity_link_path(activity)
    return nil unless activity.recordable.present?

    case activity.recordable
    when Location
      curator_location_path(activity.recordable)
    when Experience
      curator_experience_path(activity.recordable)
    when Plan
      curator_plan_path(activity.recordable)
    when AudioTour
      curator_audio_tour_path(activity.recordable)
    when ContentChange
      curator_proposal_path(activity.recordable)
    when PhotoSuggestion
      curator_photo_suggestion_path(activity.recordable) if respond_to?(:curator_photo_suggestion_path)
    end
  rescue ActionController::UrlGenerationError
    nil
  end
end

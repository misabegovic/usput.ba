# frozen_string_literal: true

module CuratorHelper
  # Generate a link path for a curator activity's recordable
  def activity_link_path(activity)
    return nil unless activity.recordable.present?

    case activity.recordable
    when Location then avo.resources_location_path(activity.recordable)
    when Experience then avo.resources_experience_path(activity.recordable)
    when Plan then avo.resources_plan_path(activity.recordable)
    when AudioTour then avo.resources_audio_tour_path(activity.recordable)
    end
  rescue ActionController::UrlGenerationError
    nil
  end
end

class ApplicationController < ActionController::Base
  include Localizable
  include Authenticatable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Report all unhandled exceptions to Rollbar
  rescue_from StandardError, with: :handle_exception

  private

  # Provide user context for Rollbar error reports
  def rollbar_person
    return nil unless current_user
    { id: current_user.uuid, username: current_user.username }
  end

  def handle_exception(exception)
    Rollbar.error(exception, rollbar_person_data: rollbar_person)
    raise exception
  end
end

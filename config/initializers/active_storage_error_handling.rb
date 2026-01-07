# frozen_string_literal: true

# Handle ActiveStorage::FileNotFoundError gracefully
# This error occurs when a blob record exists in the database but the actual
# file is missing from storage (e.g., after a deployment, storage cleanup, or corruption)
Rails.application.config.after_initialize do
  # Add error handling to the ActiveStorage representations controller
  ActiveStorage::Representations::BaseController.class_eval do
    rescue_from ActiveStorage::FileNotFoundError do |exception|
      Rails.logger.warn "[ActiveStorage] File not found for blob: #{@blob&.key || 'unknown'}"
      Rollbar.warning(exception) if defined?(Rollbar)

      # Return a 404 with a helpful message
      head :not_found
    end
  end

  # Add error handling to the blobs controller as well
  ActiveStorage::Blobs::RedirectController.class_eval do
    rescue_from ActiveStorage::FileNotFoundError do |exception|
      Rails.logger.warn "[ActiveStorage] File not found for blob: #{@blob&.key || 'unknown'}"
      Rollbar.warning(exception) if defined?(Rollbar)

      head :not_found
    end
  end

  # Also handle in the proxy controller if it exists (Rails 6.1+)
  if defined?(ActiveStorage::Blobs::ProxyController)
    ActiveStorage::Blobs::ProxyController.class_eval do
      rescue_from ActiveStorage::FileNotFoundError do |exception|
        Rails.logger.warn "[ActiveStorage] File not found for blob: #{@blob&.key || 'unknown'}"
        Rollbar.warning(exception) if defined?(Rollbar)

        head :not_found
      end
    end
  end

  if defined?(ActiveStorage::Representations::ProxyController)
    ActiveStorage::Representations::ProxyController.class_eval do
      rescue_from ActiveStorage::FileNotFoundError do |exception|
        Rails.logger.warn "[ActiveStorage] File not found for blob: #{@blob&.key || 'unknown'}"
        Rollbar.warning(exception) if defined?(Rollbar)

        head :not_found
      end
    end
  end
end

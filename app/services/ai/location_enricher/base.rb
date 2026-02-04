# frozen_string_literal: true

module Ai
  class LocationEnricher
    # Base class with shared concerns for all LocationEnricher modules
    class Base
      include Concerns::ErrorReporting
      include PromptHelper

      private

      def cultural_context
        Ai::BihContext::BIH_CULTURAL_CONTEXT
      end

      def supported_locales
        @supported_locales ||= Locale.ai_supported_codes.presence ||
          %w[en bs hr de es fr it pt nl pl cs sk sl sr]
      end

      def supported_experience_types
        @supported_experience_types ||= ExperienceType.active_keys.presence ||
          %w[culture history sport food nature adventure relaxation]
      end

      def log_info(message)
        Rails.logger.info "[LocationEnricher] #{message}"
      end

      def log_warn(message)
        Rails.logger.warn "[LocationEnricher] #{message}"
      end

      def log_error(message)
        Rails.logger.error "[LocationEnricher] #{message}"
      end
    end
  end
end

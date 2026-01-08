# frozen_string_literal: true

# Background job for processing OpenAI requests with rate limiting
# Uses Solid Queue for job processing
#
# This job is used when you want to queue OpenAI requests for background
# processing instead of blocking synchronously.
#
# Usage:
#   OpenaiRequestJob.perform_later(
#     prompt: "Your prompt",
#     schema: { type: "object", ... },
#     context: "PlanCreator",
#     callback_class: "Ai::PlanCreator",
#     callback_id: 123
#   )
class OpenaiRequestJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures with exponential backoff
  retry_on Ai::OpenaiQueue::RequestError, wait: :polynomially_longer, attempts: 5
  retry_on Ai::OpenaiQueue::RateLimitError, wait: 30.seconds, attempts: 10

  # Don't retry on configuration errors
  discard_on RubyLLM::ConfigurationError if defined?(RubyLLM::ConfigurationError)

  # @param prompt [String] The prompt to send to OpenAI
  # @param schema [Hash, nil] Optional JSON schema for structured output
  # @param context [String] Context for logging
  # @param callback_class [String, nil] Class to call back with results
  # @param callback_id [Integer, nil] ID to pass to callback
  def perform(prompt:, schema: nil, context: "OpenaiRequestJob", callback_class: nil, callback_id: nil)
    Rails.logger.info "[OpenaiRequestJob] Processing request for #{context}"

    result = Ai::OpenaiQueue.request(
      prompt: prompt,
      schema: schema,
      context: context
    )

    # If a callback is specified, call it with the result
    if callback_class.present? && callback_id.present?
      klass = callback_class.constantize
      if klass.respond_to?(:handle_openai_response)
        klass.handle_openai_response(callback_id, result)
      end
    end

    Rails.logger.info "[OpenaiRequestJob] Completed request for #{context}"
    result
  rescue Ai::OpenaiQueue::RateLimitError => e
    Rails.logger.warn "[OpenaiRequestJob] Rate limit for #{context}: #{e.message}"
    raise # Re-raise to trigger retry
  rescue Ai::OpenaiQueue::RequestError => e
    Rails.logger.error "[OpenaiRequestJob] Request failed for #{context}: #{e.message}"
    raise # Re-raise to trigger retry
  end
end

# frozen_string_literal: true

module Platform
  module DSL
    # LLMHelper - Shared LLM utilities for DSL executors
    #
    # Provides common LLM generation functionality to avoid code duplication
    # across executor modules.
    #
    # Usage:
    #   class MyExecutor
    #     extend Platform::DSL::LLMHelper
    #
    #     def some_method
    #       result = generate_with_llm("Your prompt here")
    #     end
    #   end
    #
    module LLMHelper
      # Generate content using LLM
      #
      # @param prompt [String] The prompt to send to the LLM
      # @return [String] The generated content, stripped of whitespace
      # @raise [ExecutionError] If the LLM call fails
      def generate_with_llm(prompt)
        chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
        response = chat.ask(prompt)
        response.content.strip
      rescue StandardError => e
        raise ExecutionError, "LLM greška: #{e.message}"
      end
    end
  end
end

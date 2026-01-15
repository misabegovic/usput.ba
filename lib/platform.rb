# frozen_string_literal: true

# Platform - Autonomni AI mozak za Usput.ba
#
# DSL-First arhitektura za upravljanje sadržajem kroz konverzacijski interface.
#
# Zeitwerk automatski učitava sve komponente:
# - Platform::CLI - Thor CLI interface
# - Platform::Conversation - Session management
# - Platform::Brain - RubyLLM wrapper
# - Platform::DSL - Domain Specific Language
#
module Platform
  class Error < StandardError; end

  class << self
    def root
      Rails.root.join("lib", "platform")
    end

    def version
      "0.1.0"
    end
  end
end

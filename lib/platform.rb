# frozen_string_literal: true

# Platform - DSL za upravljanje sadržajem Usput.ba
#
# DSL-First arhitektura za upravljanje sadržajem.
# Agenti koriste CLI direktno (bin/platform exec).
#
# Komponente:
# - Platform::CLI - Thor CLI interface
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

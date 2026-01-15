# frozen_string_literal: true

module Platform
  # DSL - Domain Specific Language za Platform
  #
  # LogQL-inspired DSL za upite nad podacima:
  #
  #   schema | stats
  #   locations { city: "Mostar" } | count
  #   experiences { status: "published" } | aggregate count() by city
  #
  module DSL
    class Error < Platform::Error; end
    class ParseError < Error; end
    class ExecutionError < Error; end
    class ValidationError < Error; end

    class << self
      # Parsiraj i izvrši DSL query
      def execute(query)
        ast = Parser.parse(query)
        Executor.execute(ast)
      rescue Parslet::ParseFailed => e
        raise ParseError, "Neispravan DSL: #{e.message}"
      end

      # Samo parsiraj (za validaciju)
      def parse(query)
        Parser.parse(query)
      end

      # Validiraj query bez izvršavanja
      def validate(query)
        Validator.validate(query)
      end
    end
  end
end

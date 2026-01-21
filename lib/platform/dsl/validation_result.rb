# frozen_string_literal: true

module Platform
  module DSL
    # ValidationResult - Rezultat validacije sadržaja
    #
    # Koristi se za praćenje grešaka, upozorenja i sugestija
    # tokom validacije lokacija, iskustava i drugog sadržaja.
    #
    # Primjer:
    #   result = ValidationResult.new
    #   result.add_warning("Sumnjiv obrazac u nazivu", code: :suspicious_pattern)
    #   result.valid? # => true (warnings ne blokiraju)
    #   result.status # => :warning
    #
    class ValidationResult
      attr_reader :status, :errors, :warnings, :suggestions
      attr_accessor :coordinates, :geoapify_data, :existing_record

      STATUSES = %i[valid warning invalid].freeze

      def initialize
        @status = :valid
        @errors = []
        @warnings = []
        @suggestions = []
        @coordinates = nil
        @geoapify_data = nil
        @existing_record = nil
      end

      # Dodaj grešku - automatski postavlja status na :invalid
      def add_error(message, code: nil, details: nil)
        @errors << build_issue(message, code, details)
        @status = :invalid
        self
      end

      # Dodaj upozorenje - postavlja status na :warning ako je trenutno :valid
      def add_warning(message, code: nil, details: nil)
        @warnings << build_issue(message, code, details)
        @status = :warning if @status == :valid
        self
      end

      # Dodaj sugestiju (ne utječe na status)
      def add_suggestion(message)
        @suggestions << message
        self
      end

      # Da li je validacija prošla (bez grešaka)?
      def valid?
        @status != :invalid
      end

      # Da li je potpuno čisto (bez grešaka i upozorenja)?
      def clean?
        @status == :valid
      end

      # Da li ima bilo kakvih problema?
      def has_issues?
        @errors.any? || @warnings.any?
      end

      # Spoji rezultate iz drugog ValidationResult
      def merge!(other)
        return self unless other.is_a?(ValidationResult)

        @errors.concat(other.errors)
        @warnings.concat(other.warnings)
        @suggestions.concat(other.suggestions)

        # Status se pogoršava (valid -> warning -> invalid)
        @status = :invalid if other.status == :invalid
        @status = :warning if other.status == :warning && @status == :valid

        # Preuzmi koordinate ako ih nemamo
        @coordinates ||= other.coordinates
        @geoapify_data ||= other.geoapify_data
        @existing_record ||= other.existing_record

        self
      end

      # Format za DSL output
      def to_dsl_response
        {
          status: @status,
          valid: valid?,
          errors: @errors,
          warnings: @warnings,
          suggestions: @suggestions,
          coordinates: @coordinates,
          existing_record: @existing_record&.slice(:id, :name, :city)
        }.compact
      end

      # Format za CLI prikaz
      def to_cli_output
        lines = []

        case @status
        when :valid
          lines << "✅ VALID - Validacija prošla"
        when :warning
          lines << "⚠️  WARNING - Validacija prošla sa upozorenjima"
        when :invalid
          lines << "❌ INVALID - Validacija nije prošla"
        end

        if @errors.any?
          lines << ""
          lines << "GREŠKE:"
          @errors.each { |e| lines << "  • #{e[:message]}" }
        end

        if @warnings.any?
          lines << ""
          lines << "UPOZORENJA:"
          @warnings.each { |w| lines << "  • #{w[:message]}" }
        end

        if @suggestions.any?
          lines << ""
          lines << "SUGESTIJE:"
          @suggestions.each { |s| lines << "  → #{s}" }
        end

        if @coordinates
          lines << ""
          lines << "KOORDINATE: lat=#{@coordinates[:lat]}, lng=#{@coordinates[:lng]}"
        end

        if @existing_record
          lines << ""
          lines << "POSTOJEĆI ZAPIS: ID=#{@existing_record[:id]}, #{@existing_record[:name]} (#{@existing_record[:city]})"
        end

        lines.join("\n")
      end

      private

      def build_issue(message, code, details)
        issue = { message: message }
        issue[:code] = code if code
        issue[:details] = details if details
        issue
      end
    end
  end
end

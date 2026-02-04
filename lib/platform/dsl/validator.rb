# frozen_string_literal: true

module Platform
  module DSL
    # Validator - Validira DSL queries bez izvršavanja
    #
    # Provjerava:
    # - Sintaksu (preko Parser-a)
    # - Postojanje tabela
    # - Validnost filtera
    # - Procjenu troškova
    #
    # Primjer:
    #   result = Validator.validate("locations { city: \"Mostar\" } | count")
    #   # => { valid: true, estimated_cost: :low, warnings: [] }
    #
    class Validator
      VALID_TABLES = Executor::TABLE_MAP.keys.freeze

      COST_THRESHOLDS = {
        low: 1000,      # < 1000 records
        medium: 10000,  # < 10000 records
        high: 100000    # < 100000 records
      }.freeze

      class << self
        def validate(query)
          ast = Parser.parse(query)
          errors = []
          warnings = []

          # Validate table
          if ast[:type] == :table_query
            unless VALID_TABLES.include?(ast[:table].to_s.downcase)
              errors << "Nepoznata tabela: #{ast[:table]}"
            end
          end

          # Validate operations
          ast[:operations]&.each do |op|
            unless valid_operation?(op[:name])
              errors << "Nepoznata operacija: #{op[:name]}"
            end
          end

          # Estimate cost
          cost = estimate_cost(ast)

          # Warnings
          if cost == :high
            warnings << "Ovaj query može biti spor - razmisli o dodavanju filtera"
          end

          if ast[:operations].nil? || ast[:operations].empty?
            warnings << "Query nema operacija - vraća se default limit od 100 rekorda"
          end

          {
            valid: errors.empty?,
            errors: errors,
            warnings: warnings,
            estimated_cost: cost,
            ast: ast
          }
        rescue ParseError => e
          {
            valid: false,
            errors: [ e.message ],
            warnings: [],
            estimated_cost: :unknown,
            ast: nil
          }
        end

        private

        def valid_operation?(op_name)
          %i[
            stats describe health
            count sample limit aggregate
            where select sort order
            show list
          ].include?(op_name)
        end

        def estimate_cost(ast)
          return :low if ast[:type] == :schema_query

          # Check if there are limiting filters
          has_strong_filter = ast[:filters]&.any? do |key, _|
            %i[id city status type].include?(key)
          end

          # Check if there's a limit operation
          has_limit = ast[:operations]&.any? do |op|
            %i[limit sample count].include?(op[:name])
          end

          if has_strong_filter || has_limit
            :low
          elsif ast[:filters]&.any?
            :medium
          else
            :high
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "parslet"

module Platform
  module DSL
    # Parser - Parsira DSL query u AST
    #
    # Koristi Grammar za parsing i Transform za transformaciju u AST.
    #
    # Primjer:
    #   ast = Parser.parse("locations { city: \"Mostar\" } | count")
    #   # => {
    #   #   type: :table_query,
    #   #   table: "locations",
    #   #   filters: { city: "Mostar" },
    #   #   operations: [{ name: :count }]
    #   # }
    #
    class Parser
      class << self
        def parse(query)
          tree = grammar.parse(query)
          transform.apply(tree)
        rescue Parslet::ParseFailed => e
          raise ParseError, format_error(e, query)
        end

        private

        def grammar
          @grammar ||= Grammar.new
        end

        def transform
          @transform ||= Transform.new
        end

        def format_error(error, query)
          cause = error.parse_failure_cause
          "Greška u parsiranju na poziciji #{cause.pos}: očekivano #{cause.message}\n" \
          "Query: #{query}\n" \
          "       #{' ' * cause.pos.bytepos}^"
        end
      end
    end

    # Transform - Parslet transformer za pretvaranje parse tree u AST
    class Transform < Parslet::Transform
      # Literals
      rule(integer: simple(:x)) { x.to_i }
      rule(float: simple(:x)) { x.to_f }
      rule(string: simple(:x)) { x.to_s }
      rule(boolean: simple(:x)) { x.to_s == "true" }
      rule(identifier: simple(:x)) { x.to_s.to_sym }
      rule(array: subtree(:items)) { Array(items).flatten }

      # Function calls like count(), sum(field)
      rule(function_name: simple(:fn), function_args: subtree(:args)) do
        "#{fn}(#{Array(args).join(', ')})"
      end
      rule(function_name: simple(:fn), function_args: nil) do
        "#{fn}()"
      end

      # Filter pair - convert key/value to hash entry
      rule(key: simple(:k), value: simple(:v)) do
        { k.to_s.to_sym => v }
      end
      rule(key: simple(:k), value: subtree(:v)) do
        val = v.is_a?(Hash) && v.key?(:string) ? v[:string].to_s : v
        { k.to_s.to_sym => val }
      end

      # Filters - handles both single filter and multiple filters
      rule(filters: sequence(:filter_list)) do
        # Multiple filters - array of transformed hashes
        filter_list.reduce({}) { |acc, h| acc.merge(h.is_a?(Hash) ? h : {}) }
      end
      rule(filters: subtree(:data)) do
        # Single filter or other structure
        case data
        when Hash
          if data.key?(:key) && data.key?(:value)
            # Raw key/value pair not yet transformed
            val = data[:value]
            val = val[:string].to_s if val.is_a?(Hash) && val.key?(:string)
            { data[:key].to_s.to_sym => val }
          else
            # Already a proper hash
            data
          end
        when Array
          data.reduce({}) do |acc, item|
            if item.is_a?(Hash) && item.key?(:key)
              val = item[:value]
              val = val[:string].to_s if val.is_a?(Hash) && val.key?(:string)
              acc.merge(item[:key].to_s.to_sym => val)
            else
              acc.merge(item.is_a?(Hash) ? item : {})
            end
          end
        else
          {}
        end
      end

      # Operation
      rule(operation: simple(:op)) do
        { name: op.to_s.to_sym }
      end

      rule(operation: simple(:op), args: subtree(:args)) do
        { name: op.to_s.to_sym, args: Array(args) }
      end

      rule(operation: simple(:op), args: subtree(:args), group_by: simple(:gb)) do
        { name: op.to_s.to_sym, args: Array(args), group_by: gb.to_s.to_sym }
      end

      rule(operation: simple(:op), group_by: simple(:gb)) do
        { name: op.to_s.to_sym, group_by: gb.to_s.to_sym }
      end

      # Helper to convert raw filters to hash
      def self.convert_filters(raw_filters)
        case raw_filters
        when Hash
          if raw_filters.key?(:key) && raw_filters.key?(:value)
            val = raw_filters[:value]
            val = val[:string].to_s if val.is_a?(Hash) && val.key?(:string)
            { raw_filters[:key].to_s.to_sym => val }
          else
            raw_filters
          end
        when Array
          raw_filters.reduce({}) do |acc, item|
            if item.is_a?(Hash) && item.key?(:key)
              val = item[:value]
              val = val[:string].to_s if val.is_a?(Hash) && val.key?(:string)
              acc.merge(item[:key].to_s.to_sym => val)
            elsif item.is_a?(Hash)
              acc.merge(item)
            else
              acc
            end
          end
        else
          {}
        end
      end

      # Query types
      rule(query: { table: simple(:t), filters: subtree(:f), operations: subtree(:ops) }) do
        {
          type: :table_query,
          table: t.to_s,
          filters: Transform.convert_filters(f),
          operations: Array(ops)
        }
      end

      rule(query: { table: simple(:t), filters: subtree(:f) }) do
        {
          type: :table_query,
          table: t.to_s,
          filters: Transform.convert_filters(f),
          operations: []
        }
      end

      rule(query: { table: simple(:t), operations: subtree(:ops) }) do
        {
          type: :table_query,
          table: t.to_s,
          filters: {},
          operations: Array(ops)
        }
      end

      rule(query: { table: simple(:t) }) do
        {
          type: :table_query,
          table: t.to_s,
          filters: {},
          operations: []
        }
      end

      # Schema command
      rule(query: { operations: subtree(:ops) }) do |dict|
        # Check if first operation is schema-related
        ops = Array(dict[:ops])
        if ops.first && %i[stats describe health].include?(ops.first[:name])
          {
            type: :schema_query,
            operations: ops
          }
        else
          {
            type: :table_query,
            table: "schema",
            filters: {},
            operations: ops
          }
        end
      end

      # Summaries command
      rule(query: { command_type: simple(:cmd), operations: subtree(:ops) }) do |dict|
        {
          type: :"#{dict[:cmd]}_query",
          filters: {},
          operations: Array(dict[:ops])
        }
      end

      rule(query: { command_type: simple(:cmd), filters: subtree(:f), operations: subtree(:ops) }) do |dict|
        {
          type: :"#{dict[:cmd]}_query",
          filters: Transform.convert_filters(dict[:f]),
          operations: Array(dict[:ops])
        }
      end
    end
  end
end

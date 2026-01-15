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

      # Mutation commands
      # create location { ... }
      rule(query: { mutation: simple(:m), table: simple(:t), filters: subtree(:f) }) do |dict|
        {
          type: :mutation,
          action: dict[:m].to_s.to_sym,
          table: dict[:t].to_s,
          data: Transform.convert_filters(dict[:f])
        }
      end

      # update location { id: 123 } set { ... }
      rule(query: { mutation: simple(:m), table: simple(:t), filters: subtree(:f), set_values: subtree(:sv) }) do |dict|
        {
          type: :mutation,
          action: dict[:m].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          data: Transform.convert_filters(dict[:sv])
        }
      end

      # Generation commands
      # generate description for location { id: 123 }
      rule(query: { generation: simple(:g), gen_type: simple(:gt), table: simple(:t), filters: subtree(:f), style_value: subtree(:sv) }) do |dict|
        style_val = dict[:sv].is_a?(Hash) ? dict[:sv][:string]&.to_s : dict[:sv]&.to_s
        {
          type: :generation,
          gen_type: dict[:gt].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          style: style_val
        }
      end

      # generate description without style
      rule(query: { generation: simple(:g), gen_type: simple(:gt), table: simple(:t), filters: subtree(:f) }) do |dict|
        # Only match if gen_type is description (not translations which has locales)
        next unless dict[:gt].to_s == "description"
        {
          type: :generation,
          gen_type: :description,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          style: nil
        }
      end

      # generate translations for location { id: 123 } to [en, de]
      rule(query: { generation: simple(:g), gen_type: simple(:gt), table: simple(:t), filters: subtree(:f), locales: subtree(:locs) }) do |dict|
        locales = Array(dict[:locs]).map { |l| l.is_a?(Hash) ? l[:string]&.to_s : l.to_s }
        {
          type: :generation,
          gen_type: dict[:gt].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locales: locales
        }
      end

      # generate experience from locations [1, 2, 3]
      rule(query: { generation: simple(:g), gen_type: simple(:gt), location_ids: subtree(:ids) }) do |dict|
        ids = Array(dict[:ids]).map { |id| id.is_a?(Integer) ? id : id.to_i }
        {
          type: :generation,
          gen_type: dict[:gt].to_s.to_sym,
          location_ids: ids
        }
      end

      # Audio commands
      # synthesize audio for location { id: 123 }
      rule(query: { audio_cmd: simple(:cmd), audio_type: simple(:at), table: simple(:t), filters: subtree(:f) }) do |dict|
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: nil,
          voice: nil
        }
      end

      # synthesize audio for location { id: 123 } locale "en"
      rule(query: { audio_cmd: simple(:cmd), audio_type: simple(:at), table: simple(:t), filters: subtree(:f), audio_locale: subtree(:loc) }) do |dict|
        locale_val = dict[:loc].is_a?(Hash) ? dict[:loc][:string]&.to_s : dict[:loc]&.to_s
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: locale_val,
          voice: nil
        }
      end

      # synthesize audio for location { id: 123 } voice "Rachel"
      rule(query: { audio_cmd: simple(:cmd), audio_type: simple(:at), table: simple(:t), filters: subtree(:f), voice_name: subtree(:v) }) do |dict|
        voice_val = dict[:v].is_a?(Hash) ? dict[:v][:string]&.to_s : dict[:v]&.to_s
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: nil,
          voice: voice_val
        }
      end

      # synthesize audio for location { id: 123 } locale "en" voice "Rachel"
      rule(query: { audio_cmd: simple(:cmd), audio_type: simple(:at), table: simple(:t), filters: subtree(:f), audio_locale: subtree(:loc), voice_name: subtree(:v) }) do |dict|
        locale_val = dict[:loc].is_a?(Hash) ? dict[:loc][:string]&.to_s : dict[:loc]&.to_s
        voice_val = dict[:v].is_a?(Hash) ? dict[:v][:string]&.to_s : dict[:v]&.to_s
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: locale_val,
          voice: voice_val
        }
      end

      # Approval commands
      # approve proposal { id: 123 }
      rule(query: { approval_cmd: simple(:cmd), approval_type: simple(:at), filters: subtree(:f) }) do |dict|
        {
          type: :approval,
          action: dict[:cmd].to_s.to_sym,
          approval_type: dict[:at].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          notes: nil,
          reason: nil
        }
      end

      # approve proposal { id: 123 } notes "..."
      rule(query: { approval_cmd: simple(:cmd), approval_type: simple(:at), filters: subtree(:f), approval_notes: subtree(:n) }) do |dict|
        notes_val = dict[:n].is_a?(Hash) ? dict[:n][:string]&.to_s : dict[:n]&.to_s
        {
          type: :approval,
          action: dict[:cmd].to_s.to_sym,
          approval_type: dict[:at].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          notes: notes_val,
          reason: nil
        }
      end

      # reject proposal { id: 123 } reason "..."
      rule(query: { approval_cmd: simple(:cmd), approval_type: simple(:at), filters: subtree(:f), rejection_reason: subtree(:r) }) do |dict|
        reason_val = case dict[:r]
                     when Hash
                       inner = dict[:r][:string]
                       inner.is_a?(Array) ? inner.join : inner.to_s
                     when Array then dict[:r].empty? ? "" : dict[:r].join
                     when Parslet::Slice then dict[:r].to_s
                     else dict[:r]&.to_s
                     end
        {
          type: :approval,
          action: dict[:cmd].to_s.to_sym,
          approval_type: dict[:at].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          notes: nil,
          reason: reason_val
        }
      end
    end
  end
end

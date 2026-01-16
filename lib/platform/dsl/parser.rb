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
      rule(string: sequence(:chars)) { chars.join }  # Handle empty strings: "" produces []
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
      # Note: value is always a subtree after literal transforms run bottom-up
      rule(key: simple(:k), value: subtree(:v)) do
        { k.to_s.to_sym => v }
      end

      # Filters - handles both single filter and multiple filters
      # Note: filter pairs are already transformed to hashes by the key/value rule
      rule(filters: sequence(:filter_list)) do
        filter_list.reduce({}, :merge)
      end

      rule(filters: subtree(:data)) do
        case data
        when Hash then data
        when Array then data.reduce({}, :merge)
        else {}
        end
      end

      # Operation - args is always present (may be empty) due to grammar structure
      rule(operation: simple(:op), args: subtree(:args)) do
        { name: op.to_s.to_sym, args: Array(args) }
      end

      rule(operation: simple(:op), args: subtree(:args), group_by: simple(:gb)) do
        { name: op.to_s.to_sym, args: Array(args), group_by: gb.to_s.to_sym }
      end

      # Helper to convert raw filters to hash
      # Note: filters are already transformed by the time they reach here
      def self.convert_filters(raw_filters)
        case raw_filters
        when Hash then raw_filters
        when Array then raw_filters.reduce({}, :merge)
        else {}
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

      # Summaries command and other command_type queries
      # Command with just type (no filters, no operations)
      rule(query: { command_type: simple(:cmd) }) do |dict|
        {
          type: :"#{dict[:cmd]}_query",
          filters: {},
          operations: []
        }
      end

      # Command with filters only (no operations)
      rule(query: { command_type: simple(:cmd), filters: subtree(:f) }) do |dict|
        {
          type: :"#{dict[:cmd]}_query",
          filters: Transform.convert_filters(dict[:f]),
          operations: []
        }
      end

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
        {
          type: :generation,
          gen_type: dict[:gt].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          style: dict[:sv]&.to_s
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
        {
          type: :generation,
          gen_type: dict[:gt].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locales: Array(dict[:locs]).map(&:to_s)
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
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: dict[:loc]&.to_s,
          voice: nil
        }
      end

      # synthesize audio for location { id: 123 } voice "Rachel"
      rule(query: { audio_cmd: simple(:cmd), audio_type: simple(:at), table: simple(:t), filters: subtree(:f), voice_name: subtree(:v) }) do |dict|
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: nil,
          voice: dict[:v]&.to_s
        }
      end

      # synthesize audio for location { id: 123 } locale "en" voice "Rachel"
      rule(query: { audio_cmd: simple(:cmd), audio_type: simple(:at), table: simple(:t), filters: subtree(:f), audio_locale: subtree(:loc), voice_name: subtree(:v) }) do |dict|
        {
          type: :audio,
          action: dict[:cmd].to_s.to_sym,
          audio_type: dict[:at].to_s.to_sym,
          table: dict[:t].to_s,
          filters: Transform.convert_filters(dict[:f]),
          locale: dict[:loc]&.to_s,
          voice: dict[:v]&.to_s
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
        {
          type: :approval,
          action: dict[:cmd].to_s.to_sym,
          approval_type: dict[:at].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          notes: dict[:n]&.to_s,
          reason: nil
        }
      end

      # reject proposal { id: 123 } reason "..."
      rule(query: { approval_cmd: simple(:cmd), approval_type: simple(:at), filters: subtree(:f), rejection_reason: subtree(:r) }) do |dict|
        {
          type: :approval,
          action: dict[:cmd].to_s.to_sym,
          approval_type: dict[:at].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          notes: nil,
          reason: dict[:r]&.to_s
        }
      end

      # Curator management commands
      # block curator { id: 123 } reason "spam"
      rule(query: { curator_cmd: simple(:cmd), curator_action: simple(:ca), filters: subtree(:f), rejection_reason: subtree(:r) }) do |dict|
        {
          type: :curator_management,
          action: dict[:cmd].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          reason: dict[:r]&.to_s
        }
      end

      # unblock curator { id: 123 }
      rule(query: { curator_cmd: simple(:cmd), curator_action: simple(:ca), filters: subtree(:f) }) do |dict|
        {
          type: :curator_management,
          action: dict[:cmd].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          reason: nil
        }
      end

      # Improvement commands
      # prepare fix for "description"
      rule(query: { improvement_cmd: simple(:cmd), improvement_type: simple(:t), prompt_description: subtree(:desc) }) do |dict|
        {
          type: :improvement,
          improvement_type: dict[:t].to_s.to_sym,
          description: dict[:desc]&.to_s,
          severity: nil,
          target_file: nil
        }
      end

      # prepare fix for "description" severity "high"
      rule(query: { improvement_cmd: simple(:cmd), improvement_type: simple(:t), prompt_description: subtree(:desc), prompt_severity: subtree(:sev) }) do |dict|
        {
          type: :improvement,
          improvement_type: dict[:t].to_s.to_sym,
          description: dict[:desc]&.to_s,
          severity: dict[:sev]&.to_s,
          target_file: nil
        }
      end

      # prepare fix for "description" file "path"
      rule(query: { improvement_cmd: simple(:cmd), improvement_type: simple(:t), prompt_description: subtree(:desc), target_file: subtree(:f) }) do |dict|
        {
          type: :improvement,
          improvement_type: dict[:t].to_s.to_sym,
          description: dict[:desc]&.to_s,
          severity: nil,
          target_file: dict[:f]&.to_s
        }
      end

      # prepare fix for "description" severity "high" file "path"
      rule(query: { improvement_cmd: simple(:cmd), improvement_type: simple(:t), prompt_description: subtree(:desc), prompt_severity: subtree(:sev), target_file: subtree(:f) }) do |dict|
        {
          type: :improvement,
          improvement_type: dict[:t].to_s.to_sym,
          description: dict[:desc]&.to_s,
          severity: dict[:sev]&.to_s,
          target_file: dict[:f]&.to_s
        }
      end

      # Prompt action commands
      # apply prompt { id: 123 }
      rule(query: { prompt_action: simple(:action), filters: subtree(:f) }) do |dict|
        {
          type: :prompt_action,
          action: dict[:action].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          reason: nil
        }
      end

      # reject prompt { id: 123 } reason "..."
      rule(query: { prompt_action: simple(:action), filters: subtree(:f), rejection_reason: subtree(:r) }) do |dict|
        {
          type: :prompt_action,
          action: dict[:action].to_s.to_sym,
          filters: Transform.convert_filters(dict[:f]),
          reason: dict[:r]&.to_s
        }
      end
    end
  end
end

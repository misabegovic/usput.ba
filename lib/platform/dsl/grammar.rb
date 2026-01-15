# frozen_string_literal: true

require "parslet"

module Platform
  module DSL
    # Grammar - Parslet grammar za Platform DSL
    #
    # Definira sintaksu DSL jezika:
    #
    #   schema | stats
    #   schema | describe locations
    #   locations { city: "Mostar" } | count
    #   locations { city: "Mostar", type: "restaurant" } | sample 10
    #   experiences { status: "published" } | aggregate count() by city | limit 5
    #
    class Grammar < Parslet::Parser
      # Whitespace
      rule(:space)      { match('\s').repeat(1) }
      rule(:space?)     { space.maybe }

      # Basic elements
      rule(:newline)    { match('[\n\r]') }
      rule(:digit)      { match('[0-9]') }
      rule(:letter)     { match('[a-zA-Z_]') }
      rule(:identifier) { letter >> (letter | digit).repeat }

      # Literals
      rule(:integer) do
        (str("-").maybe >> digit.repeat(1)).as(:integer)
      end

      rule(:float) do
        (str("-").maybe >> digit.repeat(1) >> str(".") >> digit.repeat(1)).as(:float)
      end

      rule(:string) do
        str('"') >> (str('\\') >> any | str('"').absent? >> any).repeat.as(:string) >> str('"')
      end

      rule(:boolean) do
        (str("true") | str("false")).as(:boolean)
      end

      rule(:array) do
        str("[") >> space? >>
        (value >> (space? >> str(",") >> space? >> value).repeat).maybe.as(:array) >>
        space? >> str("]")
      end

      rule(:value) do
        float | integer | string | boolean | array | identifier.as(:identifier)
      end

      # Filter expressions
      rule(:filter_key) { identifier.as(:key) }

      rule(:filter_pair) do
        filter_key >> space? >> str(":") >> space? >> value.as(:value)
      end

      rule(:filter_pairs) do
        filter_pair >> (space? >> str(",") >> space? >> filter_pair).repeat
      end

      rule(:filters) do
        str("{") >> space? >> filter_pairs.maybe.as(:filters) >> space? >> str("}")
      end

      # Table reference
      rule(:table_name) { identifier.as(:table) }

      rule(:table_with_filters) do
        table_name >> space? >> filters.maybe
      end

      # Function calls like count(), sum(field), avg(field)
      rule(:function_call) do
        identifier.as(:function_name) >> str("(") >> space? >>
        (value >> (space? >> str(",") >> space? >> value).repeat).maybe.as(:function_args) >>
        space? >> str(")")
      end

      # Operations
      rule(:operation_name) { identifier.as(:operation) }

      rule(:operation_arg) { function_call | value }

      rule(:by_clause) do
        str(" ") >> str("by") >> str(" ") >> identifier.as(:group_by)
      end

      # Single operation: | op_name [args] [by field]
      # Args are limited - we look ahead to ensure we don't consume next pipe
      rule(:op_arg_item) do
        (str("|").present? | str("by ").present?).absent? >> operation_arg
      end

      rule(:op_args_list) do
        op_arg_item >> (str(" ") >> op_arg_item).repeat
      end

      rule(:operation) do
        str("|") >> str(" ").maybe >> operation_name >>
        (str(" ") >> op_args_list).maybe.as(:args) >>
        by_clause.maybe
      end

      rule(:operations) do
        (operation >> str(" ").maybe).repeat(1).as(:operations)
      end

      # Schema commands (special case)
      rule(:schema_command) do
        str("schema") >> space? >> operations
      end

      # Summaries commands
      rule(:summaries_command) do
        str("summaries").as(:command_type) >> space? >> filters.maybe >> space? >> operations
      end

      # Clusters commands
      rule(:clusters_command) do
        str("clusters").as(:command_type) >> space? >> filters.maybe >> space? >> operations
      end

      # Full query
      rule(:table_query) do
        table_with_filters >> space? >> operations.maybe
      end

      rule(:query) do
        space? >> (schema_command | summaries_command | clusters_command | table_query).as(:query) >> space?
      end

      root(:query)
    end
  end
end

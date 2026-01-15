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

      # External commands (Geoapify, geocoding, etc.)
      rule(:external_command) do
        str("external").as(:command_type) >> space? >> filters.maybe >> space? >> operations
      end

      # Mutation commands
      # create location { name: "...", city: "...", lat: ..., lng: ... }
      rule(:create_command) do
        str("create").as(:mutation) >> space >> table_name >> space? >> filters
      end

      # update location { id: 123 } set { description: "..." }
      rule(:set_clause) do
        str("set") >> space? >> filters.as(:set_values)
      end

      rule(:update_command) do
        str("update").as(:mutation) >> space >> table_name >> space? >> filters >> space >> set_clause
      end

      # delete location { id: 123 }
      rule(:delete_command) do
        str("delete").as(:mutation) >> space >> table_name >> space? >> filters
      end

      # Generation commands
      # generate description for location { id: 123 }
      # generate description for location { id: 123 } style "vivid"
      rule(:style_clause) do
        space >> str("style") >> space >> string.as(:style_value)
      end

      rule(:generate_description_command) do
        str("generate").as(:generation) >> space >>
        str("description").as(:gen_type) >> space >>
        str("for") >> space >> table_name >> space? >> filters >>
        style_clause.maybe
      end

      # generate translations for location { id: 123 } to [en, de, fr]
      rule(:generate_translations_command) do
        str("generate").as(:generation) >> space >>
        str("translations").as(:gen_type) >> space >>
        str("for") >> space >> table_name >> space? >> filters >>
        space >> str("to") >> space >> array.as(:locales)
      end

      # generate experience from locations [1, 2, 3]
      rule(:generate_experience_command) do
        str("generate").as(:generation) >> space >>
        str("experience").as(:gen_type) >> space >>
        str("from") >> space >> str("locations") >> space >> array.as(:location_ids)
      end

      rule(:generation_command) do
        generate_description_command | generate_translations_command | generate_experience_command
      end

      # Audio commands
      # synthesize audio for location { id: 123 }
      # synthesize audio for location { id: 123 } locale "en"
      # synthesize audio for location { id: 123 } voice "Rachel"
      rule(:locale_clause) do
        space >> str("locale") >> space >> string.as(:audio_locale)
      end

      rule(:voice_clause) do
        space >> str("voice") >> space >> string.as(:voice_name)
      end

      rule(:synthesize_audio_command) do
        str("synthesize").as(:audio_cmd) >> space >>
        str("audio").as(:audio_type) >> space >>
        str("for") >> space >> table_name >> space? >> filters >>
        locale_clause.maybe >> voice_clause.maybe
      end

      # estimate audio cost for locations { city: "Mostar" }
      rule(:estimate_audio_command) do
        str("estimate").as(:audio_cmd) >> space >>
        str("audio") >> space >> str("cost").as(:audio_type) >> space >>
        str("for") >> space >> table_name >> space? >> filters
      end

      rule(:audio_command) do
        synthesize_audio_command | estimate_audio_command
      end

      # Approval commands
      # proposals { status: "pending" } | list
      # proposals { id: 123 } | show
      rule(:proposals_command) do
        str("proposals").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # applications { status: "pending" } | list
      # applications { id: 123 } | show
      rule(:applications_command) do
        str("applications").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # approve proposal { id: 123 }
      # approve proposal { id: 123 } notes "..."
      rule(:approval_notes_clause) do
        space >> str("notes") >> space >> string.as(:approval_notes)
      end

      rule(:approve_command) do
        str("approve").as(:approval_cmd) >> space >>
        (str("proposal") | str("application")).as(:approval_type) >> space? >> filters >>
        approval_notes_clause.maybe
      end

      # reject proposal { id: 123 } reason "..."
      rule(:rejection_reason_clause) do
        space >> str("reason") >> space >> string.as(:rejection_reason)
      end

      rule(:reject_command) do
        str("reject").as(:approval_cmd) >> space >>
        (str("proposal") | str("application")).as(:approval_type) >> space? >> filters >>
        rejection_reason_clause
      end

      rule(:approval_command) do
        approve_command | reject_command
      end

      # Curator management commands
      # curators { status: "active" } | list
      # curators { id: 123 } | activity
      rule(:curators_command) do
        str("curators").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # block curator { id: 123 } reason "spam"
      rule(:block_curator_command) do
        str("block").as(:curator_cmd) >> space >>
        str("curator").as(:curator_action) >> space? >> filters >>
        rejection_reason_clause
      end

      # unblock curator { id: 123 }
      rule(:unblock_curator_command) do
        str("unblock").as(:curator_cmd) >> space >>
        str("curator").as(:curator_action) >> space? >> filters
      end

      rule(:curator_management_command) do
        block_curator_command | unblock_curator_command
      end

      # Introspection commands
      # code { file: "path" } | read_file
      # code | search "pattern"
      rule(:code_command) do
        str("code").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # logs { last: "24h" } | errors
      # logs | slow_queries { threshold: 1000 }
      rule(:logs_command) do
        str("logs").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # infrastructure | queue_status
      # infrastructure | health
      rule(:infrastructure_command) do
        str("infrastructure").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # Self-improvement commands
      # prompts { status: "pending" } | list
      # prompts { id: 123 } | show
      rule(:prompts_command) do
        str("prompts").as(:command_type) >> space? >> filters.maybe >> space? >> operations.maybe
      end

      # prepare fix for "N+1 query in LocationsController"
      # prepare fix for "N+1 query" severity "high" file "app/controllers/locations_controller.rb"
      rule(:severity_clause) do
        space >> str("severity") >> space >> string.as(:prompt_severity)
      end

      rule(:file_clause) do
        space >> str("file") >> space >> string.as(:target_file)
      end

      rule(:prepare_fix_command) do
        str("prepare").as(:improvement_cmd) >> space >>
        str("fix").as(:improvement_type) >> space >>
        str("for") >> space >> string.as(:prompt_description) >>
        severity_clause.maybe >> file_clause.maybe
      end

      # prepare feature "Add rating to locations"
      rule(:prepare_feature_command) do
        str("prepare").as(:improvement_cmd) >> space >>
        str("feature").as(:improvement_type) >> space >>
        string.as(:prompt_description) >>
        severity_clause.maybe >> file_clause.maybe
      end

      # prepare improvement "Refactor authentication"
      rule(:prepare_improvement_command) do
        str("prepare").as(:improvement_cmd) >> space >>
        str("improvement").as(:improvement_type) >> space >>
        string.as(:prompt_description) >>
        severity_clause.maybe >> file_clause.maybe
      end

      rule(:improvement_command) do
        prepare_fix_command | prepare_feature_command | prepare_improvement_command
      end

      # apply prompt { id: 123 }
      rule(:apply_prompt_command) do
        str("apply").as(:prompt_action) >> space >>
        str("prompt") >> space? >> filters
      end

      # reject prompt { id: 123 } reason "not needed"
      rule(:reject_prompt_command) do
        str("reject").as(:prompt_action) >> space >>
        str("prompt") >> space? >> filters >>
        rejection_reason_clause
      end

      rule(:prompt_action_command) do
        apply_prompt_command | reject_prompt_command
      end

      # Full query
      rule(:table_query) do
        table_with_filters >> space? >> operations.maybe
      end

      rule(:query) do
        space? >> (schema_command | summaries_command | clusters_command | external_command | proposals_command | applications_command | curators_command | code_command | logs_command | infrastructure_command | prompts_command | approval_command | curator_management_command | improvement_command | prompt_action_command | create_command | update_command | delete_command | generation_command | audio_command | table_query).as(:query) >> space?
      end

      root(:query)
    end
  end
end

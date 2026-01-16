# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Prompts executor - prompt management, improvement, actions
      #
      # Used queries:
      #   prompts | list
      #   prompts { status: "pending" } | list
      #   prompts { id: 1 } | show
      #   prepare feature "description"
      #   apply prompt { id: 1 }
      #
      class Prompts
        extend LLMHelper

        class << self
          def execute_prompts_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :list, nil
              list_prompts(filters)
            when :show
              show_prompt(filters)
            when :count
              count_prompts(filters)
            when :pending
              list_prompts(filters.merge(status: "pending"))
            when :export
              export_prompt(filters)
            else
              list_prompts(filters)
            end
          end

          def execute_improvement(ast)
            improvement_type = ast[:improvement_type]
            description = ast[:description]
            severity = ast[:severity]
            target_file = ast[:target_file]

            raise ExecutionError, "Potreban opis za pripremu prompta" if description.blank?

            prompt_type = case improvement_type
                          when :fix then "fix"
                          when :feature then "feature"
                          when :improvement then "improvement"
                          else "fix"
                          end

            analysis, solution = analyze_improvement(description, prompt_type, target_file)

            prompt = PreparedPrompt.create!(
              prompt_type: prompt_type,
              title: generate_title(description, prompt_type),
              content: description,
              severity: severity,
              target_file: target_file,
              analysis: analysis,
              solution: solution,
              metadata: {
                created_via: "platform_dsl",
                created_at: Time.current.iso8601
              }
            )

            PlatformAuditLog.create!(
              action: "create",
              record_type: "PreparedPrompt",
              record_id: prompt.id,
              change_data: {
                prompt_type: prompt_type,
                description: description.truncate(100)
              },
              triggered_by: "platform_dsl_improvement"
            )

            {
              success: true,
              action: :prepare_prompt,
              prompt_id: prompt.id,
              type: prompt_type,
              title: prompt.title,
              severity: severity,
              message: "Prompt pripremljen. Koristi 'prompts { id: #{prompt.id} } | show' za pregled."
            }
          end

          def execute_prompt_action(ast)
            action = ast[:action]
            filters = ast[:filters]

            case action
            when :apply
              apply_prompt(filters)
            when :reject
              reject_prompt(filters, ast[:reason])
            else
              raise ExecutionError, "Nepoznata prompt akcija: #{action}"
            end
          end

          private

          def list_prompts(filters)
            scope = PreparedPrompt.all

            if filters[:status]
              status = filters[:status].to_s
              scope = scope.where(status: status) if PreparedPrompt.statuses.key?(status)
            end

            if filters[:type] || filters[:prompt_type]
              prompt_type = (filters[:type] || filters[:prompt_type]).to_s
              scope = scope.where(prompt_type: prompt_type) if PreparedPrompt.prompt_types.key?(prompt_type)
            end

            if filters[:severity]
              scope = scope.where(severity: filters[:severity]) if PreparedPrompt.severities.key?(filters[:severity].to_s)
            end

            prompts = scope.by_severity.recent.limit(50)

            {
              action: :list_prompts,
              count: prompts.size,
              total_pending: PreparedPrompt.status_pending.count,
              prompts: prompts.map(&:to_short_format)
            }
          end

          def show_prompt(filters)
            prompt = find_prompt(filters)

            {
              action: :show_prompt,
              prompt: prompt.to_full_format
            }
          end

          def count_prompts(filters)
            {
              total: PreparedPrompt.count,
              pending: PreparedPrompt.status_pending.count,
              in_progress: PreparedPrompt.status_in_progress.count,
              applied: PreparedPrompt.status_applied.count,
              rejected: PreparedPrompt.status_rejected.count,
              by_type: PreparedPrompt.group(:prompt_type).count,
              by_severity: PreparedPrompt.group(:severity).count
            }
          end

          def export_prompt(filters)
            prompt = find_prompt(filters)

            {
              action: :export_prompt,
              prompt_id: prompt.id,
              title: prompt.title,
              claude_prompt: prompt.to_claude_prompt
            }
          end

          def find_prompt(filters)
            raise ExecutionError, "Potreban filter: id" unless filters[:id]

            prompt = PreparedPrompt.find_by(id: filters[:id])
            raise ExecutionError, "Prompt sa id=#{filters[:id]} nije pronađen" unless prompt

            prompt
          end

          def apply_prompt(filters)
            prompt = find_prompt(filters)

            unless prompt.status_pending? || prompt.status_in_progress?
              raise ExecutionError, "Prompt nije u pending ili in_progress statusu (trenutni status: #{prompt.status})"
            end

            prompt.apply!

            PlatformAuditLog.create!(
              action: "update",
              record_type: "PreparedPrompt",
              record_id: prompt.id,
              change_data: {
                status: "applied",
                applied_by: "platform_dsl"
              },
              triggered_by: "platform_dsl_improvement"
            )

            {
              success: true,
              action: :apply_prompt,
              prompt_id: prompt.id,
              title: prompt.title,
              message: "Prompt je označen kao primijenjen"
            }
          end

          def reject_prompt(filters, reason)
            prompt = find_prompt(filters)

            unless prompt.status_pending? || prompt.status_in_progress?
              raise ExecutionError, "Prompt nije u pending ili in_progress statusu (trenutni status: #{prompt.status})"
            end

            raise ExecutionError, "Potreban razlog za odbijanje" if reason.blank?

            prompt.reject!(reason: reason)

            PlatformAuditLog.create!(
              action: "update",
              record_type: "PreparedPrompt",
              record_id: prompt.id,
              change_data: {
                status: "rejected",
                reason: reason,
                rejected_by: "platform_dsl"
              },
              triggered_by: "platform_dsl_improvement"
            )

            {
              success: true,
              action: :reject_prompt,
              prompt_id: prompt.id,
              title: prompt.title,
              reason: reason,
              message: "Prompt je odbijen"
            }
          end

          def analyze_improvement(description, prompt_type, target_file)
            begin
              analysis = generate_analysis(description, prompt_type, target_file)
              solution = generate_solution(description, prompt_type, target_file)
              [analysis, solution]
            rescue => e
              Rails.logger.warn "Failed to generate analysis: #{e.message}"
              [nil, nil]
            end
          end

          def generate_analysis(description, prompt_type, target_file)
            prompt = <<~PROMPT
              Analiziraj sljedeći #{prompt_type == 'fix' ? 'problem' : 'zahtjev'}:

              #{description}

              #{target_file ? "Ciljani fajl: #{target_file}" : ""}

              Napiši kratku analizu (2-3 rečenice) koja objašnjava:
              - Koji je root cause (za fixove) ili svrha (za feature)
              - Koje komponente su uključene
              - Potencijalne rizike ili ovisnosti

              Vrati SAMO tekst analize.
            PROMPT

            generate_with_llm(prompt)
          rescue
            nil
          end

          def generate_solution(description, prompt_type, target_file)
            prompt = <<~PROMPT
              Predloži rješenje za sljedeći #{prompt_type == 'fix' ? 'problem' : 'zahtjev'}:

              #{description}

              #{target_file ? "Ciljani fajl: #{target_file}" : ""}

              Napiši kratak prijedlog rješenja (3-5 bullet points) koji opisuje:
              - Ključne korake implementacije
              - Potrebne izmjene fajlova
              - Testove koje treba napisati

              Vrati SAMO bullet points, bez uvoda.
            PROMPT

            generate_with_llm(prompt)
          rescue
            nil
          end

          def generate_title(description, prompt_type)
            begin
              prompt = <<~PROMPT
                Generiši kratak naslov (max 80 karaktera) za sljedeći #{prompt_type}:

                #{description}

                Vrati SAMO naslov, bez dodatnog teksta.
              PROMPT

              title = generate_with_llm(prompt)
              title.strip.truncate(80)
            rescue
              "#{prompt_type.capitalize}: #{description.truncate(60)}"
            end
          end

          # generate_with_llm is provided by LLMHelper
        end
      end
    end
  end
end

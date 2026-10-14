# frozen_string_literal: true

module Usput
  module Commands
    # What this deployment has and lacks, as yes and no: never a key's value.
    class Doctor < Command
      named "doctor", "Check the database, the keys usput needs, the job queue, the mine data and Jev's mode (admins)"

      def call
        allow!(actor&.admin?)

        { database: database, keys: keys, jobs: jobs, mine_data: mine_data,
          reviews: { mode: ReviewModeration.config[:mode].to_s },
          llm: { default_model: RubyLLM.config.default_model } }
      end

      private

      def database
        { connected: ActiveRecord::Base.connection.select_value("SELECT 1") == 1, places: Location.not_archived.count,
          pending_migrations: ActiveRecord::Base.connection_pool.migration_context.needs_migration? }
      end

      def keys
        { llm: RubyLLM.config.openai_api_key.present? || RubyLLM.config.anthropic_api_key.present?,
          jev: RubyLLM.config.typesafe_api_key.present?,
          langfuse: LLMTracing.enabled?,
          elevenlabs: (ENV["ELEVENLABS_API_KEY"].presence || Setting.get("tts.elevenlabs_api_key")).present?,
          geoapify: Rails.application.config.geoapify.api_key.present? }
      end

      def jobs
        { waiting: SolidQueue::ReadyExecution.count, failed: SolidQueue::FailedExecution.count }
      rescue ActiveRecord::ActiveRecordError => e
        { unavailable: e.class.name }
      end

      def mine_data
        index = MineChecker::StaticIndex.instance
        { available: index.available?, as_of: index.data_as_of&.iso8601, stale: index.available? && index.stale? }
      end
    end
  end
end

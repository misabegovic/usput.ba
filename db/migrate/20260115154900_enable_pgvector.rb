# frozen_string_literal: true

class EnablePgvector < ActiveRecord::Migration[8.1]
  # Disable DDL transaction so we can handle extension errors gracefully
  disable_ddl_transaction!

  def change
    # pgvector extension for semantic search
    # Install with: sudo apt-get install postgresql-16-pgvector
    # Skip if not available (clusters will work without embeddings)
    return if pgvector_available?

    begin
      execute "CREATE EXTENSION IF NOT EXISTS vector"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("extension \"vector\" is not available")
        Rails.logger.warn "[Migration] pgvector not available - semantic search disabled"
        puts "WARNING: pgvector extension not available. Install with: sudo apt-get install postgresql-16-pgvector"
      else
        raise
      end
    end
  end

  private

  def pgvector_available?
    execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
  rescue
    false
  end
end

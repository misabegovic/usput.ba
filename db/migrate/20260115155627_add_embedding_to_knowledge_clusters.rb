# frozen_string_literal: true

class AddEmbeddingToKnowledgeClusters < ActiveRecord::Migration[8.1]
  def change
    # Skip if pgvector extension is not available
    return unless pgvector_available?

    # Add embedding column for semantic search
    add_column :knowledge_clusters, :embedding, :vector, limit: 1536

    # Add HNSW index for fast similarity search
    add_index :knowledge_clusters, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end

  private

  def pgvector_available?
    execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
  rescue
    false
  end
end

# frozen_string_literal: true

class AddEmbeddingToKnowledgeClusters < ActiveRecord::Migration[8.1]
  def change
    # Enable pgvector extension (now that it's installed)
    enable_extension "vector"

    # Add embedding column for semantic search
    add_column :knowledge_clusters, :embedding, :vector, limit: 1536

    # Add HNSW index for fast similarity search
    add_index :knowledge_clusters, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end

# frozen_string_literal: true

class CreateKnowledgeClusters < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_clusters do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :summary
      t.jsonb :stats, default: {}
      t.jsonb :representative_ids, default: []
      t.integer :member_count, default: 0

      t.timestamps

      t.index :slug, unique: true
    end

    # Add vector embedding column if pgvector is available
    if pgvector_available?
      add_column :knowledge_clusters, :embedding, :vector, limit: 1536
      add_index :knowledge_clusters, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    end
  end

  private

  def pgvector_available?
    execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
  rescue
    false
  end
end

class AddEmbeddingsToBrowses < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    # text-embedding-3-small returns 1536 dimensions (decided 2026-09-30).
    # The model and a digest of the embedded text sit beside the vector, so a
    # changed text or model is embedded again and an unchanged one is not.
    add_column :browses, :embedding, :vector, limit: 1536
    add_column :browses, :embedding_model, :string
    add_column :browses, :embedding_digest, :string
    add_index :browses, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end

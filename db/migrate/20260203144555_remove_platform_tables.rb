class RemovePlatformTables < ActiveRecord::Migration[8.1]
  def up
    # Drop foreign keys first
    remove_foreign_key :cluster_memberships, :knowledge_clusters if foreign_key_exists?(:cluster_memberships, :knowledge_clusters)
    remove_foreign_key :prepared_prompts, :users if foreign_key_exists?(:prepared_prompts, :users)

    # Drop Platform tables
    drop_table :cluster_memberships, if_exists: true
    drop_table :knowledge_clusters, if_exists: true
    drop_table :knowledge_summaries, if_exists: true
    drop_table :platform_audit_logs, if_exists: true
    drop_table :platform_conversations, if_exists: true
    drop_table :platform_statistics, if_exists: true
    drop_table :prepared_prompts, if_exists: true

    # Disable vector extension (was used for knowledge_clusters embeddings)
    disable_extension "vector" if extension_enabled?("vector")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot restore Platform tables"
  end
end

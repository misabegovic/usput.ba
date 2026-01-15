# frozen_string_literal: true

class CreateClusterMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :cluster_memberships do |t|
      t.references :knowledge_cluster, null: false, foreign_key: true
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.float :similarity_score

      t.timestamps

      t.index %i[record_type record_id]
      t.index %i[knowledge_cluster_id record_type record_id], unique: true, name: "idx_cluster_memberships_unique"
    end
  end
end

# frozen_string_literal: true

class ClusterMembership < PlatformRecord
  belongs_to :knowledge_cluster
  belongs_to :record, polymorphic: true

  validates :record_type, presence: true
  validates :record_id, presence: true
  validates :knowledge_cluster_id, uniqueness: { scope: %i[record_type record_id] }

  scope :for_locations, -> { where(record_type: "Location") }
  scope :for_experiences, -> { where(record_type: "Experience") }
  scope :by_similarity, -> { order(similarity_score: :desc) }

  # Get all records for a specific cluster
  def self.records_for_cluster(cluster)
    where(knowledge_cluster: cluster)
  end
end

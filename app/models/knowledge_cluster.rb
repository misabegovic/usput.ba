# frozen_string_literal: true

class KnowledgeCluster < PlatformRecord
  # Enable neighbor gem for semantic search (only if platform database is available)
  has_neighbors :embedding if safe_column_names.include?("embedding")

  has_many :cluster_memberships, dependent: :destroy
  has_many :locations, through: :cluster_memberships, source: :record, source_type: "Location"
  has_many :experiences, through: :cluster_memberships, source: :record, source_type: "Experience"

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  scope :by_member_count, -> { order(member_count: :desc) }
  scope :with_embedding, -> { where.not(embedding: nil) }

  # Check if semantic search is available (pgvector installed and platform db connected)
  def self.semantic_search_available?
    safe_column_names.include?("embedding")
  end

  # Find similar clusters by semantic search (requires pgvector)
  def self.semantic_search(query_embedding, limit: 5)
    return none unless semantic_search_available?
    return none if query_embedding.blank?

    # Use neighbor gem for cosine similarity search
    with_embedding.nearest_neighbors(:embedding, query_embedding, distance: "cosine").limit(limit)
  end

  # Generate embedding from summary text using OpenAI
  def generate_embedding!
    return unless self.class.semantic_search_available?
    return if summary.blank?

    embedding = Platform::Knowledge::LayerTwo.generate_embedding(summary)
    update!(embedding: embedding) if embedding.present?
  end

  # Update member count from memberships
  def refresh_member_count!
    update!(member_count: cluster_memberships.count)
  end

  # Get representative records
  def representative_records
    return [] if representative_ids.blank?

    # Load first few representative locations
    Location.where(id: representative_ids.take(5))
  end

  # Format for CLI display
  def to_short_format
    "#{name} (#{slug}) - #{member_count} members"
  end

  def to_cli_format
    lines = []
    lines << "Cluster: #{name}"
    lines << "Slug: #{slug}"
    lines << "Members: #{member_count}"
    lines << ""
    lines << "Summary:"
    lines << summary if summary.present?
    lines << ""
    lines << "Stats:"
    stats&.each do |key, value|
      lines << "  #{key}: #{value}"
    end
    if representative_ids.present?
      lines << ""
      lines << "Representative locations: #{representative_ids.take(5).join(', ')}"
    end
    lines.join("\n")
  end
end

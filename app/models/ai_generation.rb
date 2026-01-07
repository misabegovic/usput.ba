class AiGeneration < ApplicationRecord
  # Status enum
  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  # Generation types
  GENERATION_TYPES = %w[full locations_only experiences_only].freeze

  # Validations
  validates :generation_type, presence: true, inclusion: { in: GENERATION_TYPES }
  validates :city_name, presence: true
  validates :city_name, uniqueness: {
    scope: :generation_type,
    conditions: -> { where(status: [ :pending, :processing ]) },
    message: "already has a pending or processing generation of this type"
  }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(generation_type: type) }
  scope :in_progress, -> { where(status: [ :pending, :processing ]) }

  # Start generation
  def start!
    update!(status: :processing, started_at: Time.current)
  end

  # Complete generation
  def complete!(locations_count: 0, experiences_count: 0, meta: {})
    update!(
      status: :completed,
      completed_at: Time.current,
      locations_created: locations_count,
      experiences_created: experiences_count,
      metadata: metadata.merge(meta)
    )
  end

  # Fail generation
  def fail!(error)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
    )
  end

  # Duration in seconds
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  # Check if generation can be retried
  def can_retry?
    failed?
  end
end

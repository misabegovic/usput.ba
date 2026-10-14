# frozen_string_literal: true

# What a curator or admin decides about a record, written once for every door
# that can decide it: the admin's actions and the usput commands. Each change
# lands in one transaction with its event in the record's stream.
module Decisions
  MODERATION_EVENTS = {
    "Moment" => { approved: MomentApproved, rejected: MomentRejected },
    "Review" => { approved: ReviewApproved, rejected: ReviewRejected }
  }.freeze

  module_function

  # Approves or rejects a moment or a review. False when it already stood
  # there, so a repeated decision records nothing. A review also records
  # whether the curator overturned the band Jev gave it.
  def moderate(record, status, by:)
    status = status.to_sym
    event = MODERATION_EVENTS.fetch(record.class.name).fetch(status)
    return false if record.moderation_status == status.to_s

    ActiveRecord::Base.transaction do
      context = record.respond_to?(:jev_band) ? review_context(record, status) : {}
      record.update!(moderation_status: status)
      DecisionLog.publish(event, record, by:, **context)
    end
    true
  end

  def archive(location, by:)
    return false if location.archived?

    ActiveRecord::Base.transaction do
      location.archive!
      DecisionLog.publish(PlaceArchived, location, by:)
    end
    true
  end

  def restore(location, by:)
    return false unless location.archived?

    ActiveRecord::Base.transaction do
      location.restore!
      DecisionLog.publish(PlaceRestored, location, by:)
    end
    true
  end

  def review_context(review, status)
    { decided_by: "curator", overturned: review.jev_band.present? && review.jev_band != status.to_s }
  end
  private_class_method :review_context
end

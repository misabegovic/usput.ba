# frozen_string_literal: true

# PlanSuggestionContribution - Multi-curator contribution tracking
#
# When multiple curators work on the same plan suggestion,
# each contribution is tracked separately for audit trail.
#
# Has same typed columns as PlanSuggestion - only non-nil fields
# represent what this specific curator changed.
#
# Usage:
#   suggestion.add_contribution(
#     user: curator_b,
#     notes: "Added better title and experiences",
#     proposed_title: "New title...",
#     proposed_experience_days: { "1" => ["uuid1", "uuid2"] }
#   )
#
class PlanSuggestionContribution < ApplicationRecord
  belongs_to :plan_suggestion
  belongs_to :user

  validates :user_id, uniqueness: {
    scope: :plan_suggestion_id,
    message: "already contributed to this suggestion"
  }
end

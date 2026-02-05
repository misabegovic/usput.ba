# frozen_string_literal: true

# ExperienceSuggestionContribution - Multi-curator contribution tracking
#
# When multiple curators work on the same experience suggestion,
# each contribution is tracked separately for audit trail.
#
# Has same typed columns as ExperienceSuggestion - only non-nil fields
# represent what this specific curator changed.
#
# Usage:
#   suggestion.add_contribution(
#     user: curator_b,
#     notes: "Added better description",
#     proposed_description: "New description...",
#     proposed_title: "Updated title"
#   )
#
class ExperienceSuggestionContribution < ApplicationRecord
  belongs_to :experience_suggestion
  belongs_to :user

  validates :user_id, uniqueness: {
    scope: :experience_suggestion_id,
    message: "already contributed to this suggestion"
  }
end

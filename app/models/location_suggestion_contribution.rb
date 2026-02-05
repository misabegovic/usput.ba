# frozen_string_literal: true

# LocationSuggestionContribution - Multi-curator contribution tracking
#
# When multiple curators work on the same location suggestion,
# each contribution is tracked separately for audit trail.
#
# Has same typed columns as LocationSuggestion - only non-nil fields
# represent what this specific curator changed.
#
# Usage:
#   suggestion.add_contribution(
#     user: curator_b,
#     notes: "Added better description",
#     proposed_description: "New description...",
#     proposed_city: "Mostar"
#   )
#
class LocationSuggestionContribution < ApplicationRecord
  belongs_to :location_suggestion
  belongs_to :user

  validates :user_id, uniqueness: {
    scope: :location_suggestion_id,
    message: "already contributed to this suggestion"
  }
end

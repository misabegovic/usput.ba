# frozen_string_literal: true

module Curator
  module Admin
    # Unified suggestions inbox for admins.
    # Shows all pending suggestions across all resource types in one view.
    class SuggestionsController < BaseController
      def index
        @location_suggestions = LocationSuggestion.includes(:user, :location).pending_review.recent
        @experience_suggestions = ExperienceSuggestion.includes(:user, :experience).pending_review.recent
        @plan_suggestions = PlanSuggestion.includes(:user, :plan).pending_review.recent

        @stats = {
          location_pending: LocationSuggestion.pending_review.count,
          experience_pending: ExperienceSuggestion.pending_review.count,
          plan_pending: PlanSuggestion.pending_review.count,
          total_pending: LocationSuggestion.pending_review.count + ExperienceSuggestion.pending_review.count + PlanSuggestion.pending_review.count
        }
      end
    end
  end
end

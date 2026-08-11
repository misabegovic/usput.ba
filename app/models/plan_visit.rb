# frozen_string_literal: true

class PlanVisit < ApplicationRecord
  belongs_to :user
  belongs_to :plan
  belongs_to :location

  validates :location_id, uniqueness: { scope: [ :user_id, :plan_id ] }

  # One row per place, the newest check-in for it. The uniqueness above is per
  # plan, so a traveller who reached the same place on two plans has two rows;
  # Postgres drops the older one here rather than the caller loading every
  # check-in ever made to throw most of them away in Ruby.
  scope :most_recent_per_location, -> {
    where(id: unscope(:includes, :limit, :order)
                .select("DISTINCT ON (plan_visits.location_id) plan_visits.id")
                .order("plan_visits.location_id, plan_visits.created_at DESC"))
      .order(created_at: :desc)
  }
end

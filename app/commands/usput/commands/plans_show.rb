# frozen_string_literal: true

module Usput
  module Commands
    class PlansShow < Command
      named "plans.show", "One plan, day by day: its experiences and its own stops"
      param :id, :string, "The plan's id (uuid)", required: true

      def call
        plan = find!(Plan, arg(:id), "plan")
        allow!(plan.visibility_public_plan? || (actor && plan.user_id == actor.id))

        Serialize.plan(plan).merge(notes: plan.notes, days: days_of(plan))
      end

      private

      def days_of(plan)
        experiences = plan.plan_experiences.includes(:experience).group_by(&:day_number)
        stops = plan.plan_locations.includes(:location).group_by(&:day_number)
        (experiences.keys | stops.keys).sort.map do |day|
          { day:, experiences: Array(experiences[day]).map { |row| row.experience.uuid },
            stops: Array(stops[day]).reject { |row| row.location.archived? }.map { |row| row.location.uuid } }
        end
      end
    end
  end
end

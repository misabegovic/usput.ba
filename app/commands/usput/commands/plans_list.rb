# frozen_string_literal: true

module Usput
  module Commands
    class PlansList < Command
      named "plans.list", "List public plans, by city"
      param :city, :string, "The plan's city"
      param :limit, :integer, "How many, at most 100", default: 20

      def call
        scope = Plan.public_plans.without_explore_bosnia
        scope = scope.where(city_name: arg(:city)) if arg(:city)
        scope.includes(:locale_translations).order(created_at: :desc).limit(limit)
             .map { |plan| Serialize.plan(plan) }
      end
    end
  end
end

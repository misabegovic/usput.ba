# frozen_string_literal: true

module Usput
  module Commands
    class ExperiencesList < Command
      named "experiences.list", "List experiences, by title or by a city one of their places is in"
      param :query, :string, "Words in the title"
      param :city, :string, "A city one of the experience's places is in"
      param :limit, :integer, "How many, at most 100", default: 20

      def call
        scope = Experience.all
        scope = scope.where("title ILIKE ?", "%#{Experience.sanitize_sql_like(arg(:query))}%") if arg(:query)
        scope = scope.by_city_name(arg(:city)) if arg(:city)
        scope.includes(:locale_translations, :locations).order(:title).limit(limit)
             .map { |experience| Serialize.experience(experience) }
      end
    end
  end
end

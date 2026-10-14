# frozen_string_literal: true

module Usput
  module Commands
    class ExperiencesShow < Command
      named "experiences.show", "One experience with its description and its places in order"
      param :id, :string, "The experience's id (uuid)", required: true

      def call
        experience = find!(Experience, arg(:id), "experience")
        places = experience.locations.not_archived.includes(:locale_translations, *Location::CATEGORY_PRELOAD)
        Serialize.experience(experience).merge(description: experience.description, seasons: experience.seasons,
                                               places: places.map { |location| Serialize.place(location) })
      end
    end
  end
end

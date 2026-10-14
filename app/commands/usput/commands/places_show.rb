# frozen_string_literal: true

module Usput
  module Commands
    class PlacesShow < Command
      named "places.show", "One place with its description, tags, accessibility and audio tours"
      param :id, :string, "The place's id (uuid)", required: true

      def call
        location = find!(Location, arg(:id), "place")
        allow!(curator?) if location.archived?

        Serialize.place(location).merge(
          description: location.description, historical_context: location.historical_context,
          tags: location.tags, accessibility: location.accessibility,
          experiences: location.experiences.map(&:uuid),
          audio_tours: location.audio_tours.with_audio.pluck(:locale)
        )
      end
    end
  end
end

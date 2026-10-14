# frozen_string_literal: true

module Usput
  module Commands
    class PlacesRestore < Command
      named "places.restore", "Restore a place that was archived", effect: :decides
      param :id, :string, "The place's id (uuid)", required: true

      def call
        location = find!(Location, arg(:id), "place")
        allow!(AdminPolicy.new(actor, location).update?)

        changed = Decisions.restore(location, by: actor)
        Serialize.place(location.reload).merge(changed:)
      end
    end
  end
end

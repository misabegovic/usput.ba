# frozen_string_literal: true

module Usput
  module Commands
    class PlacesArchive < Command
      named "places.archive", "Archive a place: it leaves explore and every walk, and comes back with restore", effect: :decides
      param :id, :string, "The place's id (uuid)", required: true

      def call
        location = find!(Location, arg(:id), "place")
        allow!(AdminPolicy.new(actor, location).update?)

        changed = Decisions.archive(location, by: actor)
        Serialize.place(location.reload).merge(changed:)
      end
    end
  end
end

# frozen_string_literal: true

module Usput
  module Commands
    class PlacesList < Command
      named "places.list", "List places, by name, city or tag; retired ones only for curators"
      param :query, :string, "Words in the place's name"
      param :city, :string, "City name, as written on the place"
      param :tag, :string, "One tag"
      param :accessible, :boolean, "Only places marked wheelchair accessible"
      param :archived, :boolean, "Retired places instead of live ones (curators)", default: false
      param :limit, :integer, "How many, at most 100", default: 20
      param :offset, :integer, "How many to skip", default: 0

      def call
        allow!(curator?) if arg(:archived)

        scope = arg(:archived) ? Location.archived : Location.not_archived
        scope = scope.where("name ILIKE ?", "%#{Location.sanitize_sql_like(arg(:query))}%") if arg(:query)
        scope = scope.where(city: arg(:city)) if arg(:city)
        scope = scope.with_tag(arg(:tag)) if arg(:tag)
        scope = scope.wheelchair_accessible if arg(:accessible)
        scope.includes(:locale_translations, *Location::CATEGORY_PRELOAD)
             .order(:name).limit(limit).offset(arg(:offset).clamp(0, nil))
             .map { |location| Serialize.place(location) }
      end
    end
  end
end

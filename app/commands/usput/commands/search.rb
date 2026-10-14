# frozen_string_literal: true

module Usput
  module Commands
    # The explore page's search index, without the page.
    class Search < Command
      TYPES = %w[location experience plan moment].freeze

      named "search", "Search places, experiences, plans and public moments the way explore does"
      param :query, :string, "Words to search for", required: true
      param :type, :string, "Only one kind of result", enum: TYPES
      param :city, :string, "City name"
      param :limit, :integer, "How many, at most 100", default: 20

      def call
        rows = Browse.smart_search(arg(:query))
        rows = rows.where(browsable_type: arg(:type).classify) if arg(:type)
        rows = rows.by_city_name(arg(:city)) if arg(:city)
        rows = rows.limit(limit).to_a
        ids = public_ids(rows)
        rows.map do |row|
          { type: row.browsable_type.underscore, id: ids[[ row.browsable_type, row.browsable_id ]],
            title: row.title, city: row.city_name, rating: row.average_rating&.to_f }
        end
      end

      private

      # One query per kind of result for the uuids, never one per row.
      def public_ids(rows)
        rows.group_by(&:browsable_type).flat_map do |type, of_type|
          type.constantize.where(id: of_type.map(&:browsable_id)).pluck(:id, :uuid).map { |id, uuid| [ [ type, id ], uuid ] }
        end.to_h
      end
    end
  end
end

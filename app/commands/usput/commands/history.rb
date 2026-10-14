# frozen_string_literal: true

module Usput
  module Commands
    # A record's stream in Rails Event Store: who decided what, and when.
    class History < Command
      KINDS = { "place" => Location, "moment" => Moment, "review" => Review, "user" => User }.freeze

      named "history", "Every decision recorded about a place, moment, review or account (curators)"
      param :kind, :string, "place, moment, review or user", required: true, enum: KINDS.keys
      param :id, :string, "The record's id (uuid)", required: true

      def call
        allow!(curator?)

        record = find!(KINDS.fetch(arg(:kind)), arg(:id), arg(:kind))
        DecisionLog.history(record).map do |event|
          { event: event.event_type, at: event.metadata[:timestamp]&.iso8601, data: event.data }
        end
      end
    end
  end
end

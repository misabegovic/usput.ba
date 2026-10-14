# frozen_string_literal: true

# Rails Event Store keeps domain events, what happened to which record and
# who did it, in event_store_events (jsonb), one stream per record such as
# "Moment$<uuid>" (wiki/decisions/rails-event-store.md).
Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::JSONClient.new
end

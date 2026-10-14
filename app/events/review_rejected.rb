# frozen_string_literal: true

# A review was turned away, by Jev or a curator (data: decided_by); its author still sees it.
class ReviewRejected < RubyEventStore::Event
end

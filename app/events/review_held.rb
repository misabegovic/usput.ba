# frozen_string_literal: true

# A review waits for a curator, because Jev was unsure or could not answer.
class ReviewHeld < RubyEventStore::Event
end

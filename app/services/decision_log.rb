# frozen_string_literal: true

# Publishes what a curator or admin decided about a record to Rails Event
# Store, in that record's own stream ("Moment$<uuid>"), so its history reads
# in order: who approved it, who took it down, when. Records are named by
# uuid, the public id every usput URL uses, never the database id.
module DecisionLog
  def self.publish(event_class, record, by:, **data)
    event = event_class.new(data: { record: record.uuid, by: by&.uuid, **data }.compact)
    Rails.configuration.event_store.publish(event, stream_name: stream_for(record))
    event
  end

  def self.stream_for(record)
    "#{record.class.name}$#{record.uuid}"
  end

  def self.history(record)
    Rails.configuration.event_store.read.stream(stream_for(record)).to_a
  end
end

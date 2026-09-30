class Session < ApplicationRecord
  SEEN_EVERY = 1.hour

  belongs_to :user

  def touch_seen!
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at < SEEN_EVERY.ago
  end
end

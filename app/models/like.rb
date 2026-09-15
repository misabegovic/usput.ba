# frozen_string_literal: true

class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true, counter_cache: :likes_count

  validates :user_id, uniqueness: { scope: [ :likeable_type, :likeable_id ] }

  after_save :sync_likeable_to_browse
  after_destroy :sync_likeable_to_browse

  private

  # counter_cache writes likes_count with a bare UPDATE, so the likeable's own
  # after_save never fires and its Browse row would keep the count it was
  # indexed with.
  def sync_likeable_to_browse
    return if destroyed_by_association
    return unless likeable.respond_to?(:sync_to_browse)

    likeable.reload.sync_to_browse
  end
end

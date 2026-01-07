# Concern for models that can be indexed in the Browse table for full-text search
# Include this in Location, Experience, and Plan models to automatically
# sync changes to the Browse table
module Browsable
  extend ActiveSupport::Concern

  included do
    has_one :browse_entry, as: :browsable, class_name: "Browse", dependent: :destroy

    # Sync to Browse after save
    after_save :sync_to_browse

    # Remove from Browse after destroy
    after_destroy :remove_from_browse
  end

  # Sync this record to the Browse table
  def sync_to_browse
    Browse.sync_record(self)
  end

  # Remove this record from the Browse table
  def remove_from_browse
    Browse.remove_record(self)
  end

  # Check if this record should be included in Browse
  def browsable?
    Browse.syncable?(self)
  end
end

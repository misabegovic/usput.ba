# frozen_string_literal: true

class RenamePhotoSuggestionAttachments < ActiveRecord::Migration[8.1]
  def up
    # Rename existing 'photo' attachments to 'photos' for PhotoSuggestion records
    execute <<-SQL
      UPDATE active_storage_attachments
      SET name = 'photos'
      WHERE record_type = 'PhotoSuggestion' AND name = 'photo'
    SQL
  end

  def down
    # Revert back to 'photo' (note: this only works if each suggestion has 1 photo)
    execute <<-SQL
      UPDATE active_storage_attachments
      SET name = 'photo'
      WHERE record_type = 'PhotoSuggestion' AND name = 'photos'
    SQL
  end
end

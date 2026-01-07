class AddAudioTourMetadataToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :audio_tour_metadata, :jsonb
  end
end

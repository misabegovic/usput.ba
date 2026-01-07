class MigrateAudioRecordingToAudioTours < ActiveRecord::Migration[8.1]
  def up
    # Migrate existing audio_recording attachments to audio_tours
    # This is a data migration that converts the legacy single audio_recording
    # to the new multilingual audio_tours system

    say_with_time "Migrating audio_recording attachments to audio_tours" do
      migrated_count = 0

      # Find all locations with audio_recording attachments
      location_ids_with_audio = ActiveStorage::Attachment
        .where(record_type: "Location", name: "audio_recording")
        .pluck(:record_id)

      location_ids_with_audio.each do |location_id|
        # Get the attachment
        attachment = ActiveStorage::Attachment.find_by(
          record_type: "Location",
          record_id: location_id,
          name: "audio_recording"
        )

        next unless attachment

        # Check if an audio_tour already exists for this location with 'bs' locale
        existing_tour = AudioTour.find_by(location_id: location_id, locale: "bs")

        if existing_tour
          # If tour exists but has no audio, attach it
          unless existing_tour.audio_file.attached?
            # Update the attachment to point to the AudioTour instead
            attachment.update!(
              record_type: "AudioTour",
              record_id: existing_tour.id,
              name: "audio_file"
            )
            migrated_count += 1
          end
        else
          # Create a new AudioTour with the audio
          audio_tour = AudioTour.create!(
            location_id: location_id,
            locale: "bs"
          )

          # Move the attachment to the new AudioTour
          attachment.update!(
            record_type: "AudioTour",
            record_id: audio_tour.id,
            name: "audio_file"
          )
          migrated_count += 1
        end
      end

      migrated_count
    end
  end

  def down
    say_with_time "Reverting audio_tours back to audio_recording" do
      reverted_count = 0

      # Find audio_tours that were created from migration (bs locale, title "Audio tura")
      AudioTour.where(locale: "bs").find_each do |audio_tour|
        next unless audio_tour.audio_file.attached?

        attachment = audio_tour.audio_file.attachment

        # Move attachment back to Location
        attachment.update!(
          record_type: "Location",
          record_id: audio_tour.location_id,
          name: "audio_recording"
        )

        # Only destroy the audio_tour if it was created by migration (has no script)
        audio_tour.destroy if audio_tour.script.blank?
        reverted_count += 1
      end

      reverted_count
    end
  end
end
class RemoveAllPhotosFromExperiencesAndLocations < ActiveRecord::Migration[8.1]
  def up
    # Remove all cover photos from experiences
    Experience.find_each do |experience|
      experience.cover_photo.purge if experience.cover_photo.attached?
    end

    # Remove all photos from locations
    Location.find_each do |location|
      location.photos.purge if location.photos.attached?
    end
  end

  def down
    # Photos cannot be restored once deleted
    raise ActiveRecord::IrreversibleMigration
  end
end

class UpdateLocationCityForMostar < ActiveRecord::Migration[8.1]
  def up
    location = Location.find_by(uuid: "31384c85-c2e5-4bb6-81d7-79df087cc158")

    if location
      location.update!(
        city: "Mostar",
        needs_ai_regeneration: true
      )
    end
  end

  def down
    # No-op: We don't know the original city value
  end
end

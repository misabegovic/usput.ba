require "test_helper"

class AudioTourGenerateJobTest < ActiveJob::TestCase
  test "enqueues job" do
    location = Location.create!(name: "Test", city: "Sarajevo", lat: 43.8, lng: 18.4)
    user = User.create!(username: "admin_test", password: "password123", user_type: :admin)

    assert_enqueued_with(job: AudioTourGenerateJob, args: [ { location_id: location.id, locale: "bs", requested_by_id: user.id } ]) do
      AudioTourGenerateJob.perform_later(
        location_id: location.id,
        locale: "bs",
        requested_by_id: user.id
      )
    end

    location.destroy
    user.destroy
  end
end

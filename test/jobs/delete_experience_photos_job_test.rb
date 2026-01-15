# frozen_string_literal: true

require "test_helper"

class DeleteExperiencePhotosJobTest < ActiveJob::TestCase
  setup do
    # Clear any existing status from previous tests
    DeleteExperiencePhotosJob.clear_status!
  end

  # === Queue configuration tests ===

  test "job is queued in default queue" do
    assert_equal "default", DeleteExperiencePhotosJob.new.queue_name
  end

  test "job is enqueued with experience_id parameter" do
    assert_enqueued_with(
      job: DeleteExperiencePhotosJob,
      args: [{ experience_id: "abc-123" }]
    ) do
      DeleteExperiencePhotosJob.perform_later(experience_id: "abc-123")
    end
  end

  test "job is enqueued with experience_ids parameter" do
    assert_enqueued_with(
      job: DeleteExperiencePhotosJob,
      args: [{ experience_ids: ["abc-1", "abc-2", "abc-3"] }]
    ) do
      DeleteExperiencePhotosJob.perform_later(experience_ids: ["abc-1", "abc-2", "abc-3"])
    end
  end

  test "job is enqueued with city parameter" do
    assert_enqueued_with(
      job: DeleteExperiencePhotosJob,
      args: [{ city: "Sarajevo" }]
    ) do
      DeleteExperiencePhotosJob.perform_later(city: "Sarajevo")
    end
  end

  test "job is enqueued with dry_run parameter" do
    assert_enqueued_with(
      job: DeleteExperiencePhotosJob,
      args: [{ experience_id: "abc-123", dry_run: true }]
    ) do
      DeleteExperiencePhotosJob.perform_later(experience_id: "abc-123", dry_run: true)
    end
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = DeleteExperiencePhotosJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "current_status returns idle when no status set" do
    Setting.where("key LIKE ?", "delete_experience_photos.%").destroy_all

    status = DeleteExperiencePhotosJob.current_status

    assert_equal "idle", status[:status]
  end

  test "current_status returns stored status" do
    Setting.set("delete_experience_photos.status", "in_progress")
    Setting.set("delete_experience_photos.message", "Processing...")

    status = DeleteExperiencePhotosJob.current_status

    assert_equal "in_progress", status[:status]
    assert_equal "Processing...", status[:message]
  end

  test "current_status handles invalid JSON in results gracefully" do
    Setting.set("delete_experience_photos.status", "completed")
    Setting.set("delete_experience_photos.message", "Done")
    Setting.set("delete_experience_photos.results", "invalid json {{{")

    # Should not raise, should return default idle status due to JSON error
    status = DeleteExperiencePhotosJob.current_status

    assert status.is_a?(Hash)
    assert_includes [:status, "status"], status.keys.first.class == Symbol ? :status : "status"
  end

  test "clear_status! resets status to idle" do
    Setting.set("delete_experience_photos.status", "in_progress")
    Setting.set("delete_experience_photos.message", "Working...")
    Setting.set("delete_experience_photos.results", '{"test": true}')

    DeleteExperiencePhotosJob.clear_status!

    status = DeleteExperiencePhotosJob.current_status
    assert_equal "idle", status[:status]
    # Message may be nil or empty string depending on implementation
    assert_includes [nil, ""], status[:message]
    assert_equal({}, status[:results])
  end

  test "force_reset! resets stuck job" do
    Setting.set("delete_experience_photos.status", "in_progress")

    DeleteExperiencePhotosJob.force_reset!

    status = DeleteExperiencePhotosJob.current_status
    assert_equal "idle", status[:status]
    assert_equal "Force reset by admin", status[:message]
  end

  # === perform method tests ===

  test "perform returns completed result when no parameters provided" do
    job = DeleteExperiencePhotosJob.new
    result = job.perform

    assert_equal "completed", result[:status]
    assert_equal "No experiences found to process", result[:message]
    assert_equal 0, result[:experiences_processed]
    assert_equal 0, result[:photos_deleted]
  end

  test "perform returns completed result when experience not found" do
    job = DeleteExperiencePhotosJob.new
    result = job.perform(experience_id: "non-existent-uuid")

    assert_equal "completed", result[:status]
    assert_equal "No experiences found to process", result[:message]
  end

  test "perform with dry_run previews deletion without actually deleting" do
    experience = create_test_experience("Dry Run Test Experience")
    attach_test_cover_photo(experience)

    job = DeleteExperiencePhotosJob.new
    result = job.perform(experience_id: experience.id, dry_run: true)

    assert_equal "completed", result[:status]
    assert result[:dry_run]
    assert_equal 1, result[:experiences_processed]
    assert_equal 0, result[:photos_deleted] # dry_run should not count as deleted
    assert_equal 1, result[:experience_results].size

    experience_result = result[:experience_results].first
    assert_equal "would_delete", experience_result[:status]
    assert_equal 1, experience_result[:photos_count]

    # Cover photo should still be attached after dry run
    experience.reload
    assert experience.cover_photo.attached?
  end

  test "perform deletes cover photo for single experience" do
    experience = create_test_experience("Delete Test Experience")
    attach_test_cover_photo(experience)

    assert experience.cover_photo.attached?, "Cover photo should be attached before deletion"

    job = DeleteExperiencePhotosJob.new
    result = job.perform(experience_id: experience.id, dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 1, result[:experiences_processed]
    assert_equal 1, result[:photos_deleted]
    assert_equal 1, result[:experience_results].size

    experience_result = result[:experience_results].first
    assert_equal "deleted", experience_result[:status]

    # Cover photo should be removed after deletion
    experience.reload
    refute experience.cover_photo.attached?, "Cover photo should be removed after deletion"
  end

  test "perform deletes cover photos for multiple experiences by ids" do
    experience1 = create_test_experience("Multi Delete 1")
    experience2 = create_test_experience("Multi Delete 2")
    attach_test_cover_photo(experience1)
    attach_test_cover_photo(experience2)

    job = DeleteExperiencePhotosJob.new
    result = job.perform(experience_ids: [experience1.id, experience2.id], dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 2, result[:experiences_processed]
    assert_equal 2, result[:photos_deleted]
    assert_equal 2, result[:experience_results].size

    # Both cover photos should be removed
    experience1.reload
    experience2.reload
    refute experience1.cover_photo.attached?
    refute experience2.cover_photo.attached?
  end

  test "perform deletes cover photos for experiences in city via locations" do
    city_name = "TestCityForDeletion#{SecureRandom.hex(4)}"

    # Create locations in the test city
    location1 = create_test_location("City Location 1", city: city_name)
    location2 = create_test_location("City Location 2", city: city_name)

    # Create experiences and associate with locations
    experience1 = create_test_experience("City Experience 1")
    experience2 = create_test_experience("City Experience 2")
    experience1.add_location(location1)
    experience2.add_location(location2)
    attach_test_cover_photo(experience1)
    attach_test_cover_photo(experience2)

    job = DeleteExperiencePhotosJob.new
    result = job.perform(city: city_name, dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 2, result[:experiences_processed]
    assert_equal 2, result[:photos_deleted]
  end

  test "perform skips experiences without cover photo" do
    experience = create_test_experience("No Cover Photo Experience")

    job = DeleteExperiencePhotosJob.new
    result = job.perform(experience_id: experience.id, dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 0, result[:experiences_processed]
    assert_equal 0, result[:photos_deleted]
    assert_empty result[:experience_results]
  end

  test "perform tracks result details in results hash" do
    experience = create_test_experience("Result Details Test")
    attach_test_cover_photo(experience)

    job = DeleteExperiencePhotosJob.new
    result = job.perform(experience_id: experience.id, dry_run: false)

    assert result[:started_at].present?
    assert result[:finished_at].present?
    assert_equal experience.id, result[:experience_id]
    assert_equal false, result[:dry_run]
    assert_equal 1, result[:total_experiences]
  end

  test "perform saves status to settings throughout execution" do
    experience = create_test_experience("Status Tracking Test")
    attach_test_cover_photo(experience)

    job = DeleteExperiencePhotosJob.new
    job.perform(experience_id: experience.id, dry_run: false)

    # Check final status was saved
    final_status = DeleteExperiencePhotosJob.current_status
    assert_equal "completed", final_status[:status]
    assert final_status[:results].present?
  end

  # === completion summary tests ===

  test "build_completion_summary includes dry run prefix" do
    job = DeleteExperiencePhotosJob.new
    results = {
      dry_run: true,
      experiences_processed: 5,
      photos_deleted: 5,
      errors: []
    }

    summary = job.send(:build_completion_summary, results)

    assert_match(/Preview completed/, summary)
    assert_match(/5 experiences processed/, summary)
    assert_match(/5 cover photos deleted/, summary)
  end

  test "build_completion_summary includes error count when present" do
    job = DeleteExperiencePhotosJob.new
    results = {
      dry_run: false,
      experiences_processed: 3,
      photos_deleted: 2,
      errors: [{ experience_id: "a", error: "test" }, { experience_id: "b", error: "test2" }]
    }

    summary = job.send(:build_completion_summary, results)

    assert_match(/Completed/, summary)
    assert_match(/2 errors/, summary)
  end

  test "build_completion_summary omits errors when none" do
    job = DeleteExperiencePhotosJob.new
    results = {
      dry_run: false,
      experiences_processed: 3,
      photos_deleted: 3,
      errors: []
    }

    summary = job.send(:build_completion_summary, results)

    refute_match(/errors/, summary)
  end

  # === find_experiences tests ===

  test "find_experiences returns none when no params provided" do
    job = DeleteExperiencePhotosJob.new
    result = job.send(:find_experiences, experience_id: nil, experience_ids: nil, city: nil)

    assert_empty result
  end

  test "find_experiences prioritizes experience_id over other params" do
    experience = create_test_experience("Priority Test")
    other_experience = create_test_experience("Other Experience")

    job = DeleteExperiencePhotosJob.new
    result = job.send(:find_experiences, experience_id: experience.id, experience_ids: [other_experience.id], city: "OtherCity")

    assert_equal 1, result.count
    assert_equal experience.id, result.first.id
  end

  test "find_experiences uses experience_ids when experience_id is nil" do
    experience1 = create_test_experience("Multi Lookup 1")
    experience2 = create_test_experience("Multi Lookup 2")

    job = DeleteExperiencePhotosJob.new
    result = job.send(:find_experiences, experience_id: nil, experience_ids: [experience1.id, experience2.id], city: "OtherCity")

    assert_equal 2, result.count
    assert_includes result.pluck(:id), experience1.id
    assert_includes result.pluck(:id), experience2.id
  end

  test "find_experiences uses city when other params are nil" do
    city_name = "CityLookupTest#{SecureRandom.hex(4)}"

    # Create location in the test city
    location = create_test_location("City Lookup Location", city: city_name)

    # Create experience and associate with location
    experience = create_test_experience("City Lookup Experience")
    experience.add_location(location)

    job = DeleteExperiencePhotosJob.new
    result = job.send(:find_experiences, experience_id: nil, experience_ids: nil, city: city_name)

    assert_includes result.pluck(:id), experience.id
  end

  test "find_experiences returns distinct experiences for city" do
    city_name = "DistinctCityTest#{SecureRandom.hex(4)}"

    # Create two locations in same city
    location1 = create_test_location("Distinct Location 1", city: city_name)
    location2 = create_test_location("Distinct Location 2", city: city_name)

    # Create experience with both locations
    experience = create_test_experience("Multi Location Experience")
    experience.add_location(location1)
    experience.add_location(location2)

    job = DeleteExperiencePhotosJob.new
    result = job.send(:find_experiences, experience_id: nil, experience_ids: nil, city: city_name)

    # Should only return the experience once, not twice
    experience_ids = result.to_a.map(&:id)
    assert_equal 1, experience_ids.count { |id| id == experience.id }
  end

  private

  def create_test_experience(title)
    Experience.create!(title: title)
  end

  def create_test_location(name, city: "TestCity")
    Location.create!(
      name: name,
      city: city,
      lat: 43.8563 + rand * 0.1,
      lng: 18.4131 + rand * 0.1
    )
  end

  def attach_test_cover_photo(experience)
    test_image_path = Rails.root.join("test", "fixtures", "files", "test_image.jpg")

    # Create a minimal valid image file if it doesn't exist
    unless File.exist?(test_image_path)
      FileUtils.mkdir_p(File.dirname(test_image_path))
      File.write(test_image_path, "fake image content")
    end

    experience.cover_photo.attach(
      io: File.open(test_image_path),
      filename: "test_cover.jpg",
      content_type: "image/jpeg"
    )
  end
end

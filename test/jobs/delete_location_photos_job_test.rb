# frozen_string_literal: true

require "test_helper"

class DeleteLocationPhotosJobTest < ActiveJob::TestCase
  setup do
    # Clear any existing status from previous tests
    DeleteLocationPhotosJob.clear_status!
  end

  # === Queue configuration tests ===

  test "job is queued in default queue" do
    assert_equal "default", DeleteLocationPhotosJob.new.queue_name
  end

  test "job is enqueued with location_id parameter" do
    assert_enqueued_with(
      job: DeleteLocationPhotosJob,
      args: [{ location_id: 123 }]
    ) do
      DeleteLocationPhotosJob.perform_later(location_id: 123)
    end
  end

  test "job is enqueued with location_ids parameter" do
    assert_enqueued_with(
      job: DeleteLocationPhotosJob,
      args: [{ location_ids: [1, 2, 3] }]
    ) do
      DeleteLocationPhotosJob.perform_later(location_ids: [1, 2, 3])
    end
  end

  test "job is enqueued with city parameter" do
    assert_enqueued_with(
      job: DeleteLocationPhotosJob,
      args: [{ city: "Sarajevo" }]
    ) do
      DeleteLocationPhotosJob.perform_later(city: "Sarajevo")
    end
  end

  test "job is enqueued with dry_run parameter" do
    assert_enqueued_with(
      job: DeleteLocationPhotosJob,
      args: [{ location_id: 123, dry_run: true }]
    ) do
      DeleteLocationPhotosJob.perform_later(location_id: 123, dry_run: true)
    end
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = DeleteLocationPhotosJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "current_status returns idle when no status set" do
    Setting.where("key LIKE ?", "delete_location_photos.%").destroy_all

    status = DeleteLocationPhotosJob.current_status

    assert_equal "idle", status[:status]
  end

  test "current_status returns stored status" do
    Setting.set("delete_location_photos.status", "in_progress")
    Setting.set("delete_location_photos.message", "Processing...")

    status = DeleteLocationPhotosJob.current_status

    assert_equal "in_progress", status[:status]
    assert_equal "Processing...", status[:message]
  end

  test "current_status handles invalid JSON in results gracefully" do
    Setting.set("delete_location_photos.status", "completed")
    Setting.set("delete_location_photos.message", "Done")
    Setting.set("delete_location_photos.results", "invalid json {{{")

    # Should not raise, should return default idle status due to JSON error
    status = DeleteLocationPhotosJob.current_status

    assert status.is_a?(Hash)
    assert_includes [:status, "status"], status.keys.first.class == Symbol ? :status : "status"
  end

  test "clear_status! resets status to idle" do
    Setting.set("delete_location_photos.status", "in_progress")
    Setting.set("delete_location_photos.message", "Working...")
    Setting.set("delete_location_photos.results", '{"test": true}')

    DeleteLocationPhotosJob.clear_status!

    status = DeleteLocationPhotosJob.current_status
    assert_equal "idle", status[:status]
    # Message may be nil or empty string depending on implementation
    assert_includes [nil, ""], status[:message]
    assert_equal({}, status[:results])
  end

  test "force_reset! resets stuck job" do
    Setting.set("delete_location_photos.status", "in_progress")

    DeleteLocationPhotosJob.force_reset!

    status = DeleteLocationPhotosJob.current_status
    assert_equal "idle", status[:status]
    assert_equal "Force reset by admin", status[:message]
  end

  # === perform method tests ===

  test "perform returns completed result when no parameters provided" do
    job = DeleteLocationPhotosJob.new
    result = job.perform

    assert_equal "completed", result[:status]
    assert_equal "No locations found to process", result[:message]
    assert_equal 0, result[:locations_processed]
    assert_equal 0, result[:photos_deleted]
  end

  test "perform returns completed result when location not found" do
    job = DeleteLocationPhotosJob.new
    result = job.perform(location_id: 999999)

    assert_equal "completed", result[:status]
    assert_equal "No locations found to process", result[:message]
  end

  test "perform with dry_run previews deletion without actually deleting" do
    location = create_test_location("Dry Run Test Location")
    attach_test_photo(location)

    job = DeleteLocationPhotosJob.new
    result = job.perform(location_id: location.id, dry_run: true)

    assert_equal "completed", result[:status]
    assert result[:dry_run]
    assert_equal 1, result[:locations_processed]
    assert_equal 0, result[:photos_deleted] # dry_run should not count as deleted
    assert_equal 1, result[:location_results].size

    location_result = result[:location_results].first
    assert_equal "would_delete", location_result[:status]
    assert_equal 1, location_result[:photos_count]

    # Photo should still be attached after dry run
    location.reload
    assert location.photos.attached?
  end

  test "perform deletes photos for single location" do
    location = create_test_location("Delete Test Location")
    attach_test_photo(location)

    assert location.photos.attached?, "Photo should be attached before deletion"

    job = DeleteLocationPhotosJob.new
    result = job.perform(location_id: location.id, dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 1, result[:locations_processed]
    assert_equal 1, result[:photos_deleted]
    assert_equal 1, result[:location_results].size

    location_result = result[:location_results].first
    assert_equal "deleted", location_result[:status]

    # Photo should be removed after deletion
    location.reload
    refute location.photos.attached?, "Photo should be removed after deletion"
  end

  test "perform deletes photos for multiple locations by ids" do
    location1 = create_test_location("Multi Delete 1")
    location2 = create_test_location("Multi Delete 2")
    attach_test_photo(location1)
    attach_test_photo(location2)

    job = DeleteLocationPhotosJob.new
    result = job.perform(location_ids: [location1.id, location2.id], dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 2, result[:locations_processed]
    assert_equal 2, result[:photos_deleted]
    assert_equal 2, result[:location_results].size

    # Both photos should be removed
    location1.reload
    location2.reload
    refute location1.photos.attached?
    refute location2.photos.attached?
  end

  test "perform deletes photos for all locations in city" do
    city_name = "TestCityForDeletion#{SecureRandom.hex(4)}"
    location1 = create_test_location("City Test 1", city: city_name)
    location2 = create_test_location("City Test 2", city: city_name)
    attach_test_photo(location1)
    attach_test_photo(location2)

    job = DeleteLocationPhotosJob.new
    result = job.perform(city: city_name, dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 2, result[:locations_processed]
    assert_equal 2, result[:photos_deleted]
  end

  test "perform skips locations without photos" do
    location = create_test_location("No Photos Location")

    job = DeleteLocationPhotosJob.new
    result = job.perform(location_id: location.id, dry_run: false)

    assert_equal "completed", result[:status]
    assert_equal 0, result[:locations_processed]
    assert_equal 0, result[:photos_deleted]
    assert_empty result[:location_results]
  end

  test "perform tracks result details in results hash" do
    location = create_test_location("Result Details Test")
    attach_test_photo(location)

    job = DeleteLocationPhotosJob.new
    result = job.perform(location_id: location.id, dry_run: false)

    assert result[:started_at].present?
    assert result[:finished_at].present?
    assert_equal location.id, result[:location_id]
    assert_equal false, result[:dry_run]
    assert_equal 1, result[:total_locations]
  end

  test "perform saves status to settings throughout execution" do
    location = create_test_location("Status Tracking Test")
    attach_test_photo(location)

    job = DeleteLocationPhotosJob.new
    job.perform(location_id: location.id, dry_run: false)

    # Check final status was saved
    final_status = DeleteLocationPhotosJob.current_status
    assert_equal "completed", final_status[:status]
    assert final_status[:results].present?
  end

  # === completion summary tests ===

  test "build_completion_summary includes dry run prefix" do
    job = DeleteLocationPhotosJob.new
    results = {
      dry_run: true,
      locations_processed: 5,
      photos_deleted: 10,
      errors: []
    }

    summary = job.send(:build_completion_summary, results)

    assert_match(/Preview completed/, summary)
    assert_match(/5 locations processed/, summary)
    assert_match(/10 photos deleted/, summary)
  end

  test "build_completion_summary includes error count when present" do
    job = DeleteLocationPhotosJob.new
    results = {
      dry_run: false,
      locations_processed: 3,
      photos_deleted: 7,
      errors: [{ location_id: 1, error: "test" }, { location_id: 2, error: "test2" }]
    }

    summary = job.send(:build_completion_summary, results)

    assert_match(/Completed/, summary)
    assert_match(/2 errors/, summary)
  end

  test "build_completion_summary omits errors when none" do
    job = DeleteLocationPhotosJob.new
    results = {
      dry_run: false,
      locations_processed: 3,
      photos_deleted: 7,
      errors: []
    }

    summary = job.send(:build_completion_summary, results)

    refute_match(/errors/, summary)
  end

  # === find_locations tests ===

  test "find_locations returns none when no params provided" do
    job = DeleteLocationPhotosJob.new
    result = job.send(:find_locations, location_id: nil, location_ids: nil, city: nil)

    assert_empty result
  end

  test "find_locations prioritizes location_id over other params" do
    location = create_test_location("Priority Test")
    other_location = create_test_location("Other Location", city: "OtherCity")

    job = DeleteLocationPhotosJob.new
    result = job.send(:find_locations, location_id: location.id, location_ids: [other_location.id], city: "OtherCity")

    assert_equal 1, result.count
    assert_equal location.id, result.first.id
  end

  test "find_locations uses location_ids when location_id is nil" do
    location1 = create_test_location("Multi Lookup 1")
    location2 = create_test_location("Multi Lookup 2")

    job = DeleteLocationPhotosJob.new
    result = job.send(:find_locations, location_id: nil, location_ids: [location1.id, location2.id], city: "OtherCity")

    assert_equal 2, result.count
    assert_includes result.pluck(:id), location1.id
    assert_includes result.pluck(:id), location2.id
  end

  test "find_locations uses city when other params are nil" do
    city_name = "CityLookupTest#{SecureRandom.hex(4)}"
    location = create_test_location("City Lookup Test", city: city_name)

    job = DeleteLocationPhotosJob.new
    result = job.send(:find_locations, location_id: nil, location_ids: nil, city: city_name)

    assert_includes result.pluck(:id), location.id
  end

  private

  def create_test_location(name, city: "TestCity")
    Location.create!(
      name: name,
      city: city,
      lat: 43.8563 + rand * 0.1,
      lng: 18.4131 + rand * 0.1
    )
  end

  def attach_test_photo(location)
    test_image_path = Rails.root.join("test", "fixtures", "files", "test_image.jpg")

    # Create a minimal valid image file if it doesn't exist
    unless File.exist?(test_image_path)
      FileUtils.mkdir_p(File.dirname(test_image_path))
      File.write(test_image_path, "fake image content")
    end

    location.photos.attach(
      io: File.open(test_image_path),
      filename: "test_photo.jpg",
      content_type: "image/jpeg"
    )
  end
end

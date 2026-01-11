# frozen_string_literal: true

require "test_helper"

class LocationImageFinderJobTest < ActiveJob::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      description: "A test location for image finder tests",
      lat: 43.8563,
      lng: 18.4131
    )
    @job = LocationImageFinderJob.new

    # Clear any existing status
    LocationImageFinderJob.clear_status!
  end

  teardown do
    LocationImageFinderJob.clear_status!
    @location&.photos&.purge
    @location&.destroy
  end

  # ==========================================================================
  # generate_filename method tests
  # Note: generate_filename now takes content_type directly (not image hash)
  # This was fixed to use actual downloaded content_type instead of Google API's mime_type
  # ==========================================================================

  test "generate_filename uses correct extension for jpeg" do
    filename = @job.send(:generate_filename, @location, "image/jpeg")

    assert filename.end_with?(".jpg"), "Expected .jpg extension for image/jpeg"
    assert filename.start_with?(@location.name.parameterize), "Expected filename to start with location name"
  end

  test "generate_filename uses correct extension for png" do
    filename = @job.send(:generate_filename, @location, "image/png")

    assert filename.end_with?(".png"), "Expected .png extension for image/png"
  end

  test "generate_filename uses correct extension for webp" do
    filename = @job.send(:generate_filename, @location, "image/webp")

    assert filename.end_with?(".webp"), "Expected .webp extension for image/webp"
  end

  test "generate_filename uses correct extension for gif" do
    filename = @job.send(:generate_filename, @location, "image/gif")

    assert filename.end_with?(".gif"), "Expected .gif extension for image/gif"
  end

  test "generate_filename defaults to jpg for unknown mime type" do
    filename = @job.send(:generate_filename, @location, nil)

    assert filename.end_with?(".jpg"), "Expected .jpg extension for unknown mime type"
  end

  test "generate_filename generates unique filenames" do
    filenames = 10.times.map { @job.send(:generate_filename, @location, "image/jpeg") }

    assert_equal filenames.uniq.count, 10, "Expected 10 unique filenames"
  end

  # ==========================================================================
  # Verify the fix: filename extension now matches actual download content_type
  # Previously, generate_filename used image[:mime_type] from Google API,
  # which could differ from the actual downloaded file's content_type.
  # Now it uses the actual downloaded content_type.
  # ==========================================================================

  test "FIXED: filename extension matches actual downloaded content_type" do
    # After the fix, generate_filename takes content_type directly from download
    # This ensures the filename extension always matches the actual file content

    # If server returns JPEG, we get .jpg extension
    filename = @job.send(:generate_filename, @location, "image/jpeg")
    assert filename.end_with?(".jpg"), "JPEG content should get .jpg extension"

    # If server returns PNG, we get .png extension
    filename = @job.send(:generate_filename, @location, "image/png")
    assert filename.end_with?(".png"), "PNG content should get .png extension"
  end

  # ==========================================================================
  # build_locations_query tests
  # ==========================================================================

  test "build_locations_query finds locations without photos by default" do
    @location.photos.purge if @location.photos.attached?

    query = @job.send(:build_locations_query, city: nil, location_id: nil, replace_photos: false)

    assert query.exists?(id: @location.id), "Should find location without photos"
  end

  test "build_locations_query excludes locations with photos by default" do
    @location.photos.attach(
      io: StringIO.new("fake image"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    query = @job.send(:build_locations_query, city: nil, location_id: nil, replace_photos: false)

    refute query.exists?(id: @location.id), "Should NOT find location with photos when not replacing"
  end

  test "build_locations_query finds locations with photos when replace_photos is true" do
    @location.photos.attach(
      io: StringIO.new("fake image"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    query = @job.send(:build_locations_query, city: nil, location_id: nil, replace_photos: true)

    assert query.exists?(id: @location.id), "Should find location with photos when replacing"
  end

  test "build_locations_query filters by city" do
    other_location = Location.create!(name: "Other City Location", city: "Mostar", lat: 43.3438, lng: 17.8078)

    query = @job.send(:build_locations_query, city: "Sarajevo", location_id: nil, replace_photos: false)

    assert query.exists?(id: @location.id), "Should find Sarajevo location"
    refute query.exists?(id: other_location.id), "Should NOT find Mostar location"

    other_location.destroy
  end

  test "build_locations_query filters by location_id" do
    query = @job.send(:build_locations_query, city: nil, location_id: @location.id, replace_photos: false)

    assert_equal 1, query.count
    assert_equal @location.id, query.first&.id
  end

  # ==========================================================================
  # Status management tests
  # ==========================================================================

  test "current_status returns idle by default" do
    status = LocationImageFinderJob.current_status

    assert_equal "idle", status[:status]
  end

  test "save_status updates status correctly" do
    @job.send(:save_status, "in_progress", "Processing images...")

    status = LocationImageFinderJob.current_status
    assert_equal "in_progress", status[:status]
    assert_equal "Processing images...", status[:message]
  end

  test "save_status saves results as JSON" do
    results = { locations_processed: 5, images_attached: 10 }
    @job.send(:save_status, "completed", "Done", results: results)

    status = LocationImageFinderJob.current_status
    assert_equal "completed", status[:status]
    assert_equal 5, status[:results]["locations_processed"]
    assert_equal 10, status[:results]["images_attached"]
  end

  test "clear_status resets to idle" do
    @job.send(:save_status, "in_progress", "Testing...")
    LocationImageFinderJob.clear_status!

    status = LocationImageFinderJob.current_status
    assert_equal "idle", status[:status]
  end

  test "force_reset changes status back to idle" do
    @job.send(:save_status, "in_progress", "Stuck job...")
    LocationImageFinderJob.force_reset!

    status = LocationImageFinderJob.current_status
    assert_equal "idle", status[:status]
    assert_equal "Force reset by admin", status[:message]
  end

  # ==========================================================================
  # attach_image_to_location tests
  # ==========================================================================

  test "attach_image_to_location returns false for blank url" do
    image = { url: nil, mime_type: "image/jpeg" }

    result = @job.send(:attach_image_to_location, @location, image)

    assert_equal false, result
  end

  # ==========================================================================
  # process_location tests (with mocked service)
  # ==========================================================================

  test "process_location adds images found to results in dry run mode" do
    results = {
      images_found: 0,
      images_attached: 0,
      photos_removed: 0,
      locations_processed: 0,
      errors: [],
      location_results: []
    }

    mock_images = [
      { url: "https://example.com/img1.jpg", title: "Image 1", thumbnail: "thumb1", source: "source1", mime_type: "image/jpeg" }
    ]

    mock_service = Minitest::Mock.new
    mock_service.expect(:search_location, mock_images, [@location.name], city: @location.city, num: 3, creative_commons_only: false)

    @job.send(
      :process_location,
      @location,
      mock_service,
      results,
      images_per_location: 3,
      dry_run: true,
      creative_commons_only: false,
      replace_photos: false,
      index: 1,
      total: 1
    )

    mock_service.verify

    assert_equal 1, results[:images_found]
    assert_equal 1, results[:locations_processed]
    assert_equal 1, results[:location_results].count
    assert_equal @location.name, results[:location_results].first[:name]
    assert_equal 0, results[:images_attached], "Dry run should not attach images"
  end

  test "process_location handles API errors gracefully" do
    results = {
      images_found: 0,
      images_attached: 0,
      photos_removed: 0,
      locations_processed: 0,
      errors: [],
      location_results: []
    }

    mock_service = Minitest::Mock.new
    mock_service.expect(:search_location, nil, [@location.name], city: @location.city, num: 3, creative_commons_only: false) do
      raise GoogleImageSearchService::ApiError, "Test API error"
    end

    # Should not raise, but record error
    @job.send(
      :process_location,
      @location,
      mock_service,
      results,
      images_per_location: 3,
      dry_run: true,
      creative_commons_only: false,
      replace_photos: false,
      index: 1,
      total: 1
    )

    mock_service.verify

    assert_equal 1, results[:errors].count
    assert_equal "Test API error", results[:errors].first[:error]
  end

  # ==========================================================================
  # Attachment verification test
  # ==========================================================================

  test "photos are correctly attached to location with ActiveStorage" do
    # Directly test that ActiveStorage attachment works correctly
    initial_count = @location.photos.count

    @location.photos.attach(
      io: StringIO.new("test image content"),
      filename: "test-image.jpg",
      content_type: "image/jpeg"
    )

    @location.reload

    assert_equal initial_count + 1, @location.photos.count
    assert @location.photos.attached?

    # Verify filename and content type
    attachment = @location.photos.last
    assert_equal "test-image.jpg", attachment.filename.to_s
    assert_equal "image/jpeg", attachment.content_type
  end

  # ==========================================================================
  # Integration: Verify attach_image_to_location uses correct content_type
  # ==========================================================================

  test "attach_image_to_location uses downloaded content_type for filename" do
    # This test verifies the fix: the filename extension should match
    # the actual downloaded content_type, not the Google API's mime_type

    # We'll mock download_image to return a specific content_type
    mock_downloaded = {
      io: StringIO.new("test data"),
      content_type: "image/png"  # Actual content is PNG
    }

    # Mock download_image to return our test data
    @job.stub(:download_image, mock_downloaded) do
      image = {
        url: "https://example.com/image.jpg",
        mime_type: "image/jpeg"  # Google says JPEG (this should be ignored now)
      }

      initial_count = @location.photos.count
      result = @job.send(:attach_image_to_location, @location, image)

      assert_equal true, result
      @location.reload

      # Verify the attachment was created
      assert_equal initial_count + 1, @location.photos.count

      # Verify it uses the correct content_type (from download, not Google API)
      last_attachment = @location.photos.last
      assert_equal "image/png", last_attachment.content_type

      # Verify filename ends with .png (matching actual content)
      assert last_attachment.filename.to_s.end_with?(".png"),
             "Filename should end with .png to match actual content_type"
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class PhotoSuggestionTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(
      username: "test_curator",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "test_admin",
      password: "password123",
      user_type: :curator
    )
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )
  end

  teardown do
    PhotoSuggestion.destroy_all
    @location&.destroy
    @curator&.destroy
    @admin&.destroy
  end

  test "requires user" do
    suggestion = PhotoSuggestion.new(
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:user], "must exist"
  end

  test "requires location" do
    suggestion = PhotoSuggestion.new(
      user: @curator,
      photo_url: "https://example.com/photo.jpg"
    )
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:location], "must exist"
  end

  test "requires photo or photo_url" do
    suggestion = PhotoSuggestion.new(
      user: @curator,
      location: @location
    )
    assert_not suggestion.valid?
    assert suggestion.errors[:base].any? { |e| e.include?("photo") }
  end

  test "accepts photo_url" do
    suggestion = PhotoSuggestion.new(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )
    assert suggestion.valid?
  end

  test "defaults to pending status" do
    suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )
    assert suggestion.pending?
  end

  test "sanitizes description" do
    suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg",
      description: "<script>alert('xss')</script>Nice photo"
    )
    assert_not_includes suggestion.description, "<script>"
    assert_includes suggestion.description, "Nice photo"
  end

  test "reject sets status and notes" do
    suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )

    suggestion.reject!(@admin, notes: "Low quality image")

    assert suggestion.rejected?
    assert_equal @admin, suggestion.reviewed_by
    assert_equal "Low quality image", suggestion.admin_notes
    assert_not_nil suggestion.reviewed_at
  end

  test "cannot reject already reviewed suggestion" do
    suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )
    suggestion.reject!(@admin, notes: "Rejected")

    result = suggestion.reject!(@admin, notes: "Try again")
    assert_equal false, result
  end

  test "pending_review scope returns pending ordered by created_at" do
    suggestion1 = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo1.jpg",
      created_at: 2.days.ago
    )
    suggestion2 = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo2.jpg",
      created_at: 1.day.ago
    )
    suggestion2.reject!(@admin, notes: "Rejected")

    pending = PhotoSuggestion.pending_review
    assert_equal 1, pending.count
    assert_equal suggestion1.id, pending.first.id
  end

  test "for_location scope filters by location" do
    other_location = Location.create!(
      name: "Other Location",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )

    suggestion1 = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo1.jpg"
    )
    PhotoSuggestion.create!(
      user: @curator,
      location: other_location,
      photo_url: "https://example.com/photo2.jpg"
    )

    results = PhotoSuggestion.for_location(@location)
    assert_equal 1, results.count
    assert_equal suggestion1.id, results.first.id

    other_location.destroy
  end

  test "preview_url returns photo_url when no attachment" do
    suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )
    assert_equal "https://example.com/photo.jpg", suggestion.preview_url
  end

  # Test approve! method with attached photo
  test "approve attaches photo to location when photo is attached" do
    suggestion = PhotoSuggestion.new(
      user: @curator,
      location: @location
    )

    # Attach a test image
    suggestion.photo.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )
    suggestion.save!

    initial_photo_count = @location.photos.count

    result = suggestion.approve!(@admin, notes: "Great photo!")

    assert result
    assert suggestion.approved?
    assert_equal @admin, suggestion.reviewed_by
    assert_equal "Great photo!", suggestion.admin_notes
    assert_not_nil suggestion.reviewed_at

    @location.reload
    assert_equal initial_photo_count + 1, @location.photos.count
  end

  test "cannot approve already reviewed suggestion" do
    suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg"
    )
    suggestion.reject!(@admin, notes: "Rejected")

    result = suggestion.approve!(@admin, notes: "Changing mind")
    assert_equal false, result
    assert suggestion.rejected? # Still rejected
  end
end

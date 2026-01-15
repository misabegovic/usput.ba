# frozen_string_literal: true

require "test_helper"

class Platform::Services::SpamDetectorTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator
    )
    # Use unique coordinates to avoid conflicts in parallel tests
    @location = Location.create!(
      name: "Test Location #{SecureRandom.hex(4)}",
      city: "Sarajevo",
      lat: 43.8563 + rand(0.001..0.999),
      lng: 18.4131 + rand(0.001..0.999)
    )
  end

  teardown do
    CuratorActivity.delete_all
    @curator&.destroy
    @location&.destroy
  end

  test "check_curator returns error for non-curator" do
    user = User.create!(
      username: "basic_user_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123"
    )
    result = Platform::Services::SpamDetector.check_curator(user)

    assert result[:error]
    assert_equal "Not a curator", result[:error]

    user.destroy
  end

  test "check_curator returns ok for curator with normal activity" do
    result = Platform::Services::SpamDetector.check_curator(@curator)

    assert result[:ok]
    assert_not_nil result[:details]
  end

  test "check_curator returns already_blocked for blocked curator" do
    @curator.update!(spam_blocked_until: 1.day.from_now, spam_blocked_at: Time.current)
    result = Platform::Services::SpamDetector.check_curator(@curator)

    assert result[:already_blocked]
  end

  test "analyze_activity returns curator info" do
    result = Platform::Services::SpamDetector.analyze_activity(@curator)

    assert_equal @curator.id, result[:curator_id]
    assert_equal @curator.username, result[:username]
  end

  test "analyze_activity includes activity counts" do
    result = Platform::Services::SpamDetector.analyze_activity(@curator)

    assert result.key?(:hourly_count)
    assert result.key?(:daily_count)
    assert result.key?(:burst_count)
    assert result.key?(:duplicate_score)
  end

  test "analyze_activity detects hourly spam" do
    # Create activities exceeding hourly threshold
    Platform::Services::SpamDetector::HOURLY_THRESHOLD.times do
      CuratorActivity.create!(
        user: @curator,
        action: "proposal_created",
        recordable: @location
      )
    end

    result = Platform::Services::SpamDetector.analyze_activity(@curator)

    assert result[:is_spam]
    assert_includes result[:reason], "per hour"
  end

  test "analyze_activity detects burst spam" do
    # Create activities exceeding burst threshold (10 in 5 minutes)
    Platform::Services::SpamDetector::BURST_THRESHOLD.times do
      CuratorActivity.create!(
        user: @curator,
        action: "proposal_created",
        recordable: @location,
        created_at: 1.minute.ago
      )
    end

    result = Platform::Services::SpamDetector.analyze_activity(@curator)

    assert result[:is_spam]
    assert_includes result[:reason], "Burst"
  end

  test "analyze_activity detects duplicate actions" do
    # Create consecutive duplicate actions
    6.times do
      CuratorActivity.create!(
        user: @curator,
        action: "proposal_created",
        recordable: @location
      )
    end

    result = Platform::Services::SpamDetector.analyze_activity(@curator)

    assert result[:is_spam]
    assert_includes result[:reason], "Repetitive"
  end

  test "calculate_duplicate_score returns 0 for empty actions" do
    score = Platform::Services::SpamDetector.send(:calculate_duplicate_score, [])
    assert_equal 0, score
  end

  test "calculate_duplicate_score returns 0 for single action" do
    actions = [["proposal_created", "Location", 1]]
    score = Platform::Services::SpamDetector.send(:calculate_duplicate_score, actions)
    assert_equal 0, score
  end

  test "calculate_duplicate_score counts consecutive same actions" do
    actions = [
      ["proposal_created", "Location", 1],
      ["proposal_created", "Location", 1],
      ["proposal_created", "Location", 1],
      ["proposal_updated", "Location", 2]
    ]
    score = Platform::Services::SpamDetector.send(:calculate_duplicate_score, actions)
    assert_equal 3, score
  end

  test "detect_patterns returns pattern flags" do
    result = Platform::Services::SpamDetector.send(:detect_patterns, @curator.curator_activities)

    assert result.key?(:suspicious_ip_changes)
    assert result.key?(:after_hours_activity)
    assert result.key?(:bulk_deletions)
  end

  test "statistics returns curator counts" do
    stats = Platform::Services::SpamDetector.statistics

    assert stats.key?(:total_curators)
    assert stats.key?(:currently_blocked)
    assert stats.key?(:blocked_today)
    assert stats.key?(:high_activity_curators)
  end

  test "check_all checks all unblocked curators" do
    result = Platform::Services::SpamDetector.check_all

    assert result.key?(:checked)
    assert result.key?(:blocked)
    assert result.key?(:warnings)
    assert result.key?(:blocked_users)
    assert result[:checked] >= 0
  end

  test "thresholds are defined" do
    assert_equal 30, Platform::Services::SpamDetector::HOURLY_THRESHOLD
    assert_equal 150, Platform::Services::SpamDetector::DAILY_THRESHOLD
    assert_equal 10, Platform::Services::SpamDetector::BURST_THRESHOLD
    assert_equal 5, Platform::Services::SpamDetector::DUPLICATE_THRESHOLD
    assert_equal 24.hours, Platform::Services::SpamDetector::BLOCK_DURATION
  end
end

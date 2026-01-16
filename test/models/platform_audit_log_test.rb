# frozen_string_literal: true

require "test_helper"

class PlatformAuditLogTest < ActiveSupport::TestCase
  test "summary returns create message" do
    log = PlatformAuditLog.create!(
      action: "create",
      record_type: "Location",
      record_id: 1,
      triggered_by: "test"
    )

    assert_equal "Created Location #1", log.summary
  end

  test "summary returns update message with fields" do
    log = PlatformAuditLog.create!(
      action: "update",
      record_type: "Location",
      record_id: 1,
      change_data: { "changes" => { "name" => ["Old", "New"], "city" => ["A", "B"] } },
      triggered_by: "test"
    )

    summary = log.summary
    assert summary.include?("Updated Location #1")
    assert summary.include?("name") || summary.include?("city")
  end

  test "summary returns update message for unknown fields" do
    log = PlatformAuditLog.create!(
      action: "update",
      record_type: "Location",
      record_id: 1,
      change_data: {},
      triggered_by: "test"
    )

    summary = log.summary
    assert summary.include?("Updated Location #1")
    assert summary.include?("unknown fields")
  end

  test "summary returns delete message" do
    log = PlatformAuditLog.create!(
      action: "delete",
      record_type: "Location",
      record_id: 1,
      triggered_by: "test"
    )

    assert_equal "Deleted Location #1", log.summary
  end

  test "all valid actions return summary" do
    %w[create update delete].each do |action_type|
      log = PlatformAuditLog.create!(
        action: action_type,
        record_type: "Location",
        record_id: 1,
        triggered_by: "test"
      )
      assert_not_nil log.summary, "#{action_type} should return summary"
    end
  end

  test "recent scope returns recent logs" do
    old_log = PlatformAuditLog.create!(
      action: "create",
      record_type: "Test",
      record_id: 1,
      triggered_by: "test",
      created_at: 2.days.ago
    )
    new_log = PlatformAuditLog.create!(
      action: "create",
      record_type: "Test",
      record_id: 2,
      triggered_by: "test"
    )

    recent = PlatformAuditLog.recent
    assert_includes recent, new_log
  end

  test "for_record returns logs for specific record" do
    log1 = PlatformAuditLog.create!(
      action: "create",
      record_type: "Location",
      record_id: 1,
      triggered_by: "test"
    )
    log2 = PlatformAuditLog.create!(
      action: "create",
      record_type: "Location",
      record_id: 2,
      triggered_by: "test"
    )

    result = PlatformAuditLog.for_record("Location", 1)
    assert_includes result, log1
    assert_not_includes result, log2
  end
end

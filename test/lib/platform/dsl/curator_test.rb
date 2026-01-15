# frozen_string_literal: true

require "test_helper"

class Platform::DSL::CuratorTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      user_type: :curator,
      password: "securepassword123"
    )

    @curator2 = User.create!(
      username: "curator2_#{SecureRandom.hex(4)}",
      user_type: :curator,
      password: "securepassword123"
    )

    @location = Location.create!(
      name: "Test Lokacija",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      description: "Test opis"
    )

    # Create some activities for the curator
    CuratorActivity.create!(
      user: @curator,
      action: "proposal_created",
      recordable: @location
    )

    CuratorActivity.create!(
      user: @curator,
      action: "review_added",
      recordable: @location
    )
  end

  # Parser tests - Curators queries
  test "parses curators list command" do
    ast = Platform::DSL::Parser.parse('curators { status: "active" } | list')

    assert_equal :curators_query, ast[:type]
    assert_equal "active", ast[:filters][:status]
  end

  test "parses curators show command" do
    ast = Platform::DSL::Parser.parse('curators { id: 123 } | show')

    assert_equal :curators_query, ast[:type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses curators activity command" do
    ast = Platform::DSL::Parser.parse('curators { id: 123 } | activity')

    assert_equal :curators_query, ast[:type]
    assert_equal :activity, ast[:operations].first[:name]
  end

  test "parses curators check_spam command" do
    ast = Platform::DSL::Parser.parse('curators | check_spam')

    assert_equal :curators_query, ast[:type]
    assert_equal :check_spam, ast[:operations].first[:name]
  end

  # Parser tests - Block/Unblock commands
  test "parses block curator command" do
    ast = Platform::DSL::Parser.parse('block curator { id: 123 } reason "spam aktivnost"')

    assert_equal :curator_management, ast[:type]
    assert_equal :block, ast[:action]
    assert_equal 123, ast[:filters][:id]
    assert_equal "spam aktivnost", ast[:reason]
  end

  test "parses unblock curator command" do
    ast = Platform::DSL::Parser.parse('unblock curator { id: 123 }')

    assert_equal :curator_management, ast[:type]
    assert_equal :unblock, ast[:action]
    assert_equal 123, ast[:filters][:id]
  end

  # Execution tests - List curators
  test "lists all curators" do
    result = Platform::DSL.execute('curators | list')

    assert_equal :list_curators, result[:action]
    assert result[:count] >= 2
    assert result[:curators].any? { |c| c[:id] == @curator.id }
  end

  test "lists active curators only" do
    @curator2.block_for_spam!("test block")

    result = Platform::DSL.execute('curators { status: "active" } | list')

    assert_equal :list_curators, result[:action]
    assert result[:curators].any? { |c| c[:id] == @curator.id }
    refute result[:curators].any? { |c| c[:id] == @curator2.id }
  end

  test "lists blocked curators only" do
    @curator.block_for_spam!("test block")

    result = Platform::DSL.execute('curators { status: "blocked" } | list')

    assert_equal :list_curators, result[:action]
    assert result[:curators].any? { |c| c[:id] == @curator.id }
  end

  # Execution tests - Show curator
  test "shows curator details" do
    result = Platform::DSL.execute("curators { id: #{@curator.id} } | show")

    assert_equal :show_curator, result[:action]
    assert_equal @curator.id, result[:id]
    assert_equal @curator.username, result[:username]
    assert_equal "curator", result[:user_type]
    assert_equal false, result[:spam_blocked]
  end

  test "shows curator by username" do
    result = Platform::DSL.execute("curators { username: \"#{@curator.username}\" } | show")

    assert_equal :show_curator, result[:action]
    assert_equal @curator.id, result[:id]
  end

  # Execution tests - Curator activity
  test "shows curator activity" do
    result = Platform::DSL.execute("curators { id: #{@curator.id} } | activity")

    assert_equal :curator_activity, result[:action]
    assert_equal @curator.id, result[:curator_id]
    assert result[:activities].size >= 2
    assert result[:summary].present?
  end

  # Execution tests - Check spam
  test "checks spam for specific curator" do
    result = Platform::DSL.execute("curators { id: #{@curator.id} } | check_spam")

    assert_equal :check_spam, result[:action]
    assert_equal @curator.id, result[:curator_id]
    assert result[:result].present?
  end

  test "checks spam for all curators" do
    result = Platform::DSL.execute('curators | check_spam')

    assert_equal :check_spam_all, result[:action]
    assert result[:result][:checked] >= 2
    assert result[:statistics].present?
  end

  # Execution tests - Count curators
  test "counts curators" do
    result = Platform::DSL.execute('curators | count')

    assert result[:total] >= 2
    assert result[:active] >= 1
  end

  # Execution tests - Block curator
  test "blocks curator" do
    result = Platform::DSL.execute("block curator { id: #{@curator.id} } reason \"spam aktivnost\"")

    assert result[:success]
    assert_equal :block_curator, result[:action]
    assert_equal @curator.id, result[:curator_id]
    assert_equal "spam aktivnost", result[:reason]

    @curator.reload
    assert @curator.spam_blocked?
    assert_equal "spam aktivnost", @curator.spam_block_reason
  end

  test "blocks curator by username" do
    result = Platform::DSL.execute("block curator { username: \"#{@curator.username}\" } reason \"spam\"")

    assert result[:success]

    @curator.reload
    assert @curator.spam_blocked?
  end

  test "rejects blocking without reason" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("block curator { id: #{@curator.id} } reason \"\"")
    end

    assert_match(/razlog/i, error.message)
  end

  test "rejects blocking already blocked curator" do
    @curator.block_for_spam!("already blocked")

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("block curator { id: #{@curator.id} } reason \"double block\"")
    end

    assert_match(/već blokiran/i, error.message)
  end

  # Execution tests - Unblock curator
  test "unblocks curator" do
    @curator.block_for_spam!("test block")

    result = Platform::DSL.execute("unblock curator { id: #{@curator.id} }")

    assert result[:success]
    assert_equal :unblock_curator, result[:action]
    assert_equal @curator.id, result[:curator_id]

    @curator.reload
    refute @curator.spam_blocked?
  end

  test "rejects unblocking non-blocked curator" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("unblock curator { id: #{@curator.id} }")
    end

    assert_match(/nije blokiran/i, error.message)
  end

  # Error handling
  test "rejects non-existent curator" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("curators { id: 999999 } | show")
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "rejects non-curator user" do
    basic_user = User.create!(
      username: "basic_user_#{SecureRandom.hex(4)}",
      user_type: :basic,
      password: "securepassword123"
    )

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("curators { id: #{basic_user.id} } | show")
    end

    assert_match(/nije kurator/i, error.message)
  end

  # Audit logging
  test "creates audit log for blocking" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("block curator { id: #{@curator.id} } reason \"test\"")
    end

    log = PlatformAuditLog.last
    assert_equal "update", log.action
    assert_equal "User", log.record_type
    assert_equal "platform_dsl_curator", log.triggered_by
  end

  test "creates audit log for unblocking" do
    @curator.block_for_spam!("test")

    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("unblock curator { id: #{@curator.id} }")
    end

    log = PlatformAuditLog.last
    assert_equal "update", log.action
    assert_equal "User", log.record_type
  end
end

# SpamDetector service tests
class Platform::Services::SpamDetectorTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(
      username: "spam_test_curator_#{SecureRandom.hex(4)}",
      user_type: :curator,
      password: "securepassword123"
    )

    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
  end

  test "detects normal activity as ok" do
    # Use varied actions to avoid duplicate detection
    %w[proposal_created review_added photo_suggested login].each do |action|
      CuratorActivity.create!(
        user: @curator,
        action: action,
        recordable: @location
      )
    end

    result = Platform::Services::SpamDetector.check_curator(@curator, auto_block: false)

    assert result[:ok]
    refute result[:blocked]
  end

  test "detects burst activity as spam" do
    12.times do
      CuratorActivity.create!(
        user: @curator,
        action: "proposal_created",
        recordable: @location,
        created_at: 2.minutes.ago
      )
    end

    result = Platform::Services::SpamDetector.check_curator(@curator, auto_block: false)

    assert result[:blocked]
    assert_match(/burst/i, result[:reason])
  end

  test "check_all returns summary" do
    result = Platform::Services::SpamDetector.check_all

    assert result[:checked] >= 1
    assert_kind_of Integer, result[:blocked]
    assert_kind_of Array, result[:warnings]
  end

  test "statistics returns curator stats" do
    stats = Platform::Services::SpamDetector.statistics

    assert stats[:total_curators] >= 1
    assert_kind_of Integer, stats[:currently_blocked]
    assert_kind_of Integer, stats[:blocked_today]
  end
end

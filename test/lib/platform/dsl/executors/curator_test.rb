# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::CuratorTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    @user = User.create!(
      username: "curator_test_user_#{SecureRandom.hex(4)}",
      email: "curator_test_user_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      user_type: :basic
    )

    @curator = User.create!(
      username: "curator_#{SecureRandom.hex(4)}",
      email: "curator_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator
    )

    @admin = User.create!(
      username: "admin_#{SecureRandom.hex(4)}",
      email: "admin_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      user_type: :admin
    )
  end

  # ===================
  # Curators Query Tests
  # ===================

  test "execute_curators_query lists curators" do
    ast = { filters: {} }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :list_curators, result[:action]
    assert result[:curators].is_a?(Array)
    assert result[:total_curators] >= 0
  end

  test "execute_curators_query lists active curators" do
    ast = { filters: { status: "active" } }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :list_curators, result[:action]
  end

  test "execute_curators_query lists blocked curators" do
    @curator.update!(spam_blocked_until: 1.day.from_now, spam_block_reason: "Test block")

    ast = { filters: { status: "blocked" } }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :list_curators, result[:action]
    assert result[:curators].any? { |c| c[:username] == @curator.username }
  end

  test "execute_curators_query shows single curator" do
    ast = {
      filters: { id: @curator.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :show_curator, result[:action]
    assert_equal @curator.id, result[:id]
    assert_equal @curator.username, result[:username]
  end

  test "execute_curators_query shows curator by username" do
    ast = {
      filters: { username: @curator.username },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :show_curator, result[:action]
    assert_equal @curator.username, result[:username]
  end

  test "execute_curators_query raises for non-existent curator" do
    ast = {
      filters: { id: 999999 },
      operations: [ { name: :show } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_curators_query(ast)
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "execute_curators_query raises for non-curator user" do
    ast = {
      filters: { id: @user.id },
      operations: [ { name: :show } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_curators_query(ast)
    end

    assert_match(/nije kurator/i, error.message)
  end

  test "execute_curators_query shows curator activity" do
    ast = {
      filters: { id: @curator.id },
      operations: [ { name: :activity } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :curator_activity, result[:action]
    assert_equal @curator.id, result[:curator_id]
    assert result[:activities].is_a?(Array)
    assert result[:summary].is_a?(Hash)
  end

  test "execute_curators_query checks spam for single curator" do
    ast = {
      filters: { id: @curator.id },
      operations: [ { name: :check_spam } ]
    }

    Platform::Services::SpamDetector.stub(:check_curator, { spam_detected: false }) do
      result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

      assert_equal :check_spam, result[:action]
      assert_equal @curator.id, result[:curator_id]
    end
  end

  test "execute_curators_query checks spam for all curators" do
    ast = {
      filters: {},
      operations: [ { name: :check_spam } ]
    }

    Platform::Services::SpamDetector.stub(:check_all, { checked: 5 }) do
      Platform::Services::SpamDetector.stub(:statistics, { total_checks: 100 }) do
        result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

        assert_equal :check_spam_all, result[:action]
      end
    end
  end

  test "execute_curators_query counts curators" do
    ast = {
      filters: {},
      operations: [ { name: :count } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert result.key?(:total)
    assert result.key?(:active)
    assert result.key?(:blocked)
    assert result.key?(:high_activity)
  end

  test "execute_curators_query returns stats" do
    ast = {
      filters: {},
      operations: [ { name: :stats } ]
    }

    Platform::Services::SpamDetector.stub(:statistics, { total: 100 }) do
      result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

      assert result.is_a?(Hash)
    end
  end

  # ===================
  # Curator Management Tests
  # ===================

  test "execute_curator_management blocks curator" do
    ast = {
      action: :block,
      filters: { id: @curator.id },
      reason: "Suspicious activity"
    }

    result = Platform::DSL::Executors::Curator.execute_curator_management(ast)

    assert result[:success]
    assert_equal :block_curator, result[:action]
    assert_equal @curator.id, result[:curator_id]

    @curator.reload
    assert @curator.spam_blocked?
  end

  test "execute_curator_management raises when blocking without reason" do
    ast = {
      action: :block,
      filters: { id: @curator.id },
      reason: nil
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_curator_management(ast)
    end

    assert_match(/razlog/i, error.message)
  end

  test "execute_curator_management raises when curator already blocked" do
    @curator.update!(spam_blocked_until: 1.day.from_now, spam_block_reason: "Previous block")

    ast = {
      action: :block,
      filters: { id: @curator.id },
      reason: "Another reason"
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_curator_management(ast)
    end

    assert_match(/već blokiran/i, error.message)
  end

  test "execute_curator_management unblocks curator" do
    @curator.update!(spam_blocked_until: 1.day.from_now, spam_block_reason: "Test block")

    ast = {
      action: :unblock,
      filters: { id: @curator.id }
    }

    result = Platform::DSL::Executors::Curator.execute_curator_management(ast)

    assert result[:success]
    assert_equal :unblock_curator, result[:action]
    assert_equal @curator.id, result[:curator_id]

    @curator.reload
    assert_not @curator.spam_blocked?
  end

  test "execute_curator_management raises when curator not blocked" do
    ast = {
      action: :unblock,
      filters: { id: @curator.id }
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_curator_management(ast)
    end

    assert_match(/nije blokiran/i, error.message)
  end

  test "execute_curator_management raises for unknown action" do
    ast = {
      action: :unknown_action,
      filters: { id: @curator.id }
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_curator_management(ast)
    end

    assert_match(/Nepoznata curator management akcija/i, error.message)
  end

  # ===================
  # Edge Cases and Helper Tests
  # ===================

  test "find_curator raises without id or username filter" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.send(:find_curator, {})
    end

    assert_match(/Potreban filter: id ili username/i, error.message)
  end

  test "platform_admin_user returns admin user" do
    admin = Platform::DSL::Executors::Curator.send(:platform_admin_user)

    assert admin.admin?
  end

  test "format_curator returns correct structure" do
    result = Platform::DSL::Executors::Curator.send(:format_curator, @curator)

    assert_equal @curator.id, result[:id]
    assert_equal @curator.username, result[:username]
    assert_equal false, result[:spam_blocked]
  end

  # Additional branch coverage tests - else cases

  test "execute_curators_query with unknown operation falls back to list" do
    ast = {
      filters: {},
      operations: [ { name: :unknown_operation } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :list_curators, result[:action]
  end

  # Additional branch coverage tests for specific uncovered branches

  test "list_curators with high_activity filter" do
    # Set curator with high activity
    @curator.update!(activity_count_today: User::MAX_ACTIVITIES_PER_DAY)

    ast = { filters: { high_activity: true } }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :list_curators, result[:action]
    assert result[:curators].is_a?(Array)
  end

  test "show_curator for blocked curator includes spam_blocked_until" do
    @curator.update!(spam_blocked_until: 1.day.from_now, spam_block_reason: "Test block")

    ast = {
      filters: { id: @curator.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :show_curator, result[:action]
    assert result[:spam_blocked_until].present?
  end

  test "create_platform_user handles error when no admin exists" do
    # This is tricky to test directly - let's test via stub
    User.stub(:admin, User.none) do
      User.stub(:create!, ->(_opts) { raise "Failed to create" }) do
        error = assert_raises(Platform::DSL::ExecutionError) do
          Platform::DSL::Executors::Curator.send(:create_platform_user)
        end

        assert_match(/Nije moguće pronaći admin korisnika/i, error.message)
      end
    end
  end

  test "create_platform_user creates new user when no admin exists" do
    # Test line 422-428: when User.admin.first returns nil
    # Remove all admins
    User.where(user_type: :admin).destroy_all

    result = Platform::DSL::Executors::Curator.send(:create_platform_user)

    # Should have created a new admin user
    assert result.admin?
    assert_equal "platform_system", result.username
  end
end

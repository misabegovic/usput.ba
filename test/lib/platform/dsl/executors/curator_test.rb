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
      password: "password123",
      password_confirmation: "password123",
      user_type: :basic
    )

    @curator = User.create!(
      username: "curator_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator
    )

    @admin = User.create!(
      username: "admin_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :admin
    )

    @content_change = ContentChange.create!(
      user: @user,
      changeable: @location,
      change_type: :update_content,
      proposed_data: { name: "Updated Location" },
      original_data: { name: @location.name },
      status: :pending
    )

    @curator_application = CuratorApplication.create!(
      user: @user,
      motivation: "I want to contribute to the platform and help improve content quality. " * 5,
      experience: "5 years in travel blogging"
    )
  end

  # ===================
  # Proposals Query Tests
  # ===================

  test "execute_proposals_query lists pending proposals by default" do
    ast = { filters: {} }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :list_proposals, result[:action]
    assert result[:proposals].is_a?(Array)
    assert result[:total_pending] >= 0
  end

  test "execute_proposals_query lists proposals with status filter" do
    ast = { filters: { status: "pending" } }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :list_proposals, result[:action]
    assert result[:proposals].all? { |p| p[:status] == "pending" }
  end

  test "execute_proposals_query lists proposals with change_type filter" do
    ast = { filters: { change_type: "update_content" } }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :list_proposals, result[:action]
  end

  test "execute_proposals_query lists proposals with content_type filter" do
    ast = { filters: { content_type: "location" } }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :list_proposals, result[:action]
  end

  test "execute_proposals_query shows single proposal" do
    ast = {
      filters: { id: @content_change.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :show_proposal, result[:action]
    assert_equal @content_change.id, result[:id]
    assert_equal "pending", result[:status]
  end

  test "execute_proposals_query raises for non-existent proposal" do
    ast = {
      filters: { id: 999999 },
      operations: [ { name: :show } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_proposals_query(ast)
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "execute_proposals_query counts proposals" do
    ast = {
      filters: {},
      operations: [ { name: :count } ]
    }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert result.key?(:pending)
    assert result.key?(:approved)
    assert result.key?(:rejected)
    assert result.key?(:total)
    assert result.key?(:by_type)
    assert result.key?(:by_content_type)
  end

  # ===================
  # Applications Query Tests
  # ===================

  test "execute_applications_query lists pending applications by default" do
    ast = { filters: {} }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    assert_equal :list_applications, result[:action]
    assert result[:applications].is_a?(Array)
    assert result[:total_pending] >= 0
  end

  test "execute_applications_query shows single application" do
    ast = {
      filters: { id: @curator_application.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    assert_equal :show_application, result[:action]
    assert_equal @curator_application.id, result[:id]
    assert result[:motivation].present?
  end

  test "execute_applications_query raises for non-existent application" do
    ast = {
      filters: { id: 999999 },
      operations: [ { name: :show } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_applications_query(ast)
    end

    assert_match(/nije pronađena/i, error.message)
  end

  test "execute_applications_query counts applications" do
    ast = {
      filters: {},
      operations: [ { name: :count } ]
    }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    assert result.key?(:pending)
    assert result.key?(:approved)
    assert result.key?(:rejected)
    assert result.key?(:total)
  end

  # ===================
  # Approval Tests
  # ===================

  test "execute_approval approves proposal" do
    ast = {
      action: :approve,
      approval_type: :proposal,
      filters: { id: @content_change.id },
      notes: "Looks good"
    }

    result = Platform::DSL::Executors::Curator.execute_approval(ast)

    assert result[:success]
    assert_equal :approve_proposal, result[:action]
    assert_equal @content_change.id, result[:proposal_id]

    @content_change.reload
    assert_equal "approved", @content_change.status
  end

  test "execute_approval rejects proposal" do
    ast = {
      action: :reject,
      approval_type: :proposal,
      filters: { id: @content_change.id },
      reason: "Not accurate information"
    }

    result = Platform::DSL::Executors::Curator.execute_approval(ast)

    assert result[:success]
    assert_equal :reject_proposal, result[:action]
    assert_equal @content_change.id, result[:proposal_id]

    @content_change.reload
    assert_equal "rejected", @content_change.status
  end

  test "execute_approval raises for rejection without reason" do
    ast = {
      action: :reject,
      approval_type: :proposal,
      filters: { id: @content_change.id },
      reason: nil
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/razlog/i, error.message)
  end

  test "execute_approval approves application" do
    ast = {
      action: :approve,
      approval_type: :application,
      filters: { id: @curator_application.id },
      notes: "Welcome aboard"
    }

    result = Platform::DSL::Executors::Curator.execute_approval(ast)

    assert result[:success]
    assert_equal :approve_application, result[:action]
    assert_equal @curator_application.id, result[:application_id]

    @curator_application.reload
    assert_equal "approved", @curator_application.status

    @user.reload
    assert @user.curator?
  end

  test "execute_approval rejects application" do
    ast = {
      action: :reject,
      approval_type: :application,
      filters: { id: @curator_application.id },
      reason: "Insufficient experience"
    }

    result = Platform::DSL::Executors::Curator.execute_approval(ast)

    assert result[:success]
    assert_equal :reject_application, result[:action]
    assert_equal @curator_application.id, result[:application_id]

    @curator_application.reload
    assert_equal "rejected", @curator_application.status
  end

  test "execute_approval raises for unknown action" do
    ast = {
      action: :unknown_action,
      approval_type: :proposal,
      filters: { id: @content_change.id }
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/Nepoznata approval akcija/i, error.message)
  end

  test "execute_approval raises for non-pending proposal" do
    @content_change.update!(status: :approved)

    ast = {
      action: :approve,
      approval_type: :proposal,
      filters: { id: @content_change.id },
      notes: "Trying again"
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/nije u pending statusu/i, error.message)
  end

  test "execute_approval raises for non-pending application" do
    @curator_application.update!(status: :approved)

    ast = {
      action: :approve,
      approval_type: :application,
      filters: { id: @curator_application.id },
      notes: "Trying again"
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/nije u pending statusu/i, error.message)
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

  test "find_proposal raises without id filter" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.send(:find_proposal, {})
    end

    assert_match(/Potreban filter: id/i, error.message)
  end

  test "find_application raises without id filter" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.send(:find_application, {})
    end

    assert_match(/Potreban filter: id/i, error.message)
  end

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

  test "format_proposal returns correct structure" do
    result = Platform::DSL::Executors::Curator.send(:format_proposal, @content_change)

    assert_equal @content_change.id, result[:id]
    assert_equal "pending", result[:status]
    assert_equal "update_content", result[:change_type]
  end

  test "format_application returns correct structure" do
    result = Platform::DSL::Executors::Curator.send(:format_application, @curator_application)

    assert_equal @curator_application.id, result[:id]
    assert_equal "pending", result[:status]
    assert result[:motivation_preview].present?
  end

  test "format_curator returns correct structure" do
    result = Platform::DSL::Executors::Curator.send(:format_curator, @curator)

    assert_equal @curator.id, result[:id]
    assert_equal @curator.username, result[:username]
    assert_equal false, result[:spam_blocked]
  end

  # Additional branch coverage tests - else cases

  test "execute_proposals_query with unknown operation falls back to list" do
    ast = {
      filters: {},
      operations: [ { name: :unknown_operation } ]
    }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :list_proposals, result[:action]
  end

  test "execute_applications_query with unknown operation falls back to list" do
    ast = {
      filters: {},
      operations: [ { name: :unknown_operation } ]
    }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    assert_equal :list_applications, result[:action]
  end

  test "execute_curators_query with unknown operation falls back to list" do
    ast = {
      filters: {},
      operations: [ { name: :unknown_operation } ]
    }

    result = Platform::DSL::Executors::Curator.execute_curators_query(ast)

    assert_equal :list_curators, result[:action]
  end

  # Additional branch coverage tests for specific uncovered branches

  test "list_proposals with invalid status filter ignores it" do
    ast = { filters: { status: "invalid_status_xyz" } }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    # Should still return results (invalid status is ignored)
    assert_equal :list_proposals, result[:action]
    assert result[:proposals].is_a?(Array)
  end

  test "list_applications with invalid status filter ignores it" do
    ast = { filters: { status: "invalid_status_xyz" } }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    # Should still return results (invalid status is ignored)
    assert_equal :list_applications, result[:action]
    assert result[:applications].is_a?(Array)
  end

  test "show_proposal for reviewed proposal includes reviewed_at" do
    @content_change.update!(status: :approved, reviewed_at: Time.current)

    ast = {
      filters: { id: @content_change.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :show_proposal, result[:action]
    assert result[:reviewed_at].present?
  end

  test "show_application for reviewed application includes reviewed_at" do
    @curator_application.update!(status: :approved, reviewed_at: Time.current)

    ast = {
      filters: { id: @curator_application.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    assert_equal :show_application, result[:action]
    assert result[:reviewed_at].present?
  end

  test "approve_proposal raises when approval fails" do
    # Create a mock proposal that returns false for approve!
    mock_proposal = @content_change
    mock_proposal.define_singleton_method(:approve!) { |_admin, **_opts| false }

    Platform::DSL::Executors::Curator.stub(:find_proposal, ->(_filters) { mock_proposal }) do
      ast = {
        action: :approve,
        approval_type: :proposal,
        filters: { id: @content_change.id },
        notes: "Should fail"
      }

      error = assert_raises(Platform::DSL::ExecutionError) do
        Platform::DSL::Executors::Curator.execute_approval(ast)
      end

      assert_match(/nije uspjelo/i, error.message)
    end
  end

  test "reject_proposal raises for non-pending proposal" do
    @content_change.update!(status: :approved)

    ast = {
      action: :reject,
      approval_type: :proposal,
      filters: { id: @content_change.id },
      reason: "Some reason"
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/nije u pending statusu/i, error.message)
  end

  test "reject_application raises for non-pending application" do
    @curator_application.update!(status: :approved)

    ast = {
      action: :reject,
      approval_type: :application,
      filters: { id: @curator_application.id },
      reason: "Some reason"
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/nije u pending statusu/i, error.message)
  end

  test "reject_application raises without reason" do
    ast = {
      action: :reject,
      approval_type: :application,
      filters: { id: @curator_application.id },
      reason: ""
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.execute_approval(ast)
    end

    assert_match(/razlog/i, error.message)
  end

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

  test "list_proposals with type alias filter" do
    # Test the :type alias for :change_type
    ast = { filters: { type: "update_content" } }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :list_proposals, result[:action]
  end

  test "list_proposals with invalid change_type filter ignores it" do
    # Test line 131: if ContentChange.change_types.key?(change_type) - false branch
    ast = { filters: { change_type: "invalid_change_type_xyz" } }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    # Should still return results (invalid change_type is ignored)
    assert_equal :list_proposals, result[:action]
    assert result[:proposals].is_a?(Array)
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

  test "show_proposal for unreviewed proposal has nil reviewed_at" do
    # Test line 176: reviewed_at&.iso8601 when nil
    @content_change.update_column(:reviewed_at, nil)

    ast = {
      filters: { id: @content_change.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_proposals_query(ast)

    assert_equal :show_proposal, result[:action]
    assert_nil result[:reviewed_at]
  end

  test "show_application for unreviewed application has nil reviewed_at" do
    # Test line 254: reviewed_at&.iso8601 when nil
    @curator_application.update_column(:reviewed_at, nil)

    ast = {
      filters: { id: @curator_application.id },
      operations: [ { name: :show } ]
    }

    result = Platform::DSL::Executors::Curator.execute_applications_query(ast)

    assert_equal :show_application, result[:action]
    assert_nil result[:reviewed_at]
  end
end

# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ApprovalTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      user_type: :admin,
      password: "securepassword123"
    )

    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      user_type: :curator,
      password: "securepassword123"
    )

    @regular_user = User.create!(
      username: "test_user_#{SecureRandom.hex(4)}",
      user_type: :basic,
      password: "securepassword123"
    )

    @location = Location.create!(
      name: "Test Lokacija",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      description: "Originalni opis"
    )

    # Create a pending proposal
    @proposal = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "description" => "Originalni opis" },
      proposed_data: { "description" => "Novi opis lokacije" },
      status: :pending
    )

    # Create a pending curator application
    @application = CuratorApplication.create!(
      user: @regular_user,
      motivation: "Želim doprinijeti turističkoj ponudi BiH jer volim ovu zemlju i njene ljepote.",
      experience: "Imam 5 godina iskustva u turizmu"
    )
  end

  # Parser tests - Proposals commands
  test "parses proposals list command" do
    ast = Platform::DSL::Parser.parse('proposals { status: "pending" } | list')

    assert_equal :proposals_query, ast[:type]
    assert_equal "pending", ast[:filters][:status]
  end

  test "parses proposals show command" do
    ast = Platform::DSL::Parser.parse('proposals { id: 123 } | show')

    assert_equal :proposals_query, ast[:type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses proposals without filters" do
    ast = Platform::DSL::Parser.parse('proposals | list')

    assert_equal :proposals_query, ast[:type]
  end

  # Parser tests - Applications commands
  test "parses applications list command" do
    ast = Platform::DSL::Parser.parse('applications { status: "pending" } | list')

    assert_equal :applications_query, ast[:type]
    assert_equal "pending", ast[:filters][:status]
  end

  test "parses applications show command" do
    ast = Platform::DSL::Parser.parse('applications { id: 456 } | show')

    assert_equal :applications_query, ast[:type]
    assert_equal 456, ast[:filters][:id]
  end

  # Parser tests - Approve commands
  test "parses approve proposal command" do
    ast = Platform::DSL::Parser.parse('approve proposal { id: 123 }')

    assert_equal :approval, ast[:type]
    assert_equal :approve, ast[:action]
    assert_equal :proposal, ast[:approval_type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses approve proposal with notes" do
    ast = Platform::DSL::Parser.parse('approve proposal { id: 123 } notes "Odlična izmjena"')

    assert_equal :approval, ast[:type]
    assert_equal :approve, ast[:action]
    assert_equal "Odlična izmjena", ast[:notes]
  end

  test "parses approve application command" do
    ast = Platform::DSL::Parser.parse('approve application { id: 789 }')

    assert_equal :approval, ast[:type]
    assert_equal :approve, ast[:action]
    assert_equal :application, ast[:approval_type]
    assert_equal 789, ast[:filters][:id]
  end

  # Parser tests - Reject commands
  test "parses reject proposal command" do
    ast = Platform::DSL::Parser.parse('reject proposal { id: 123 } reason "Netačne informacije"')

    assert_equal :approval, ast[:type]
    assert_equal :reject, ast[:action]
    assert_equal :proposal, ast[:approval_type]
    assert_equal "Netačne informacije", ast[:reason]
  end

  test "parses reject application command" do
    ast = Platform::DSL::Parser.parse('reject application { id: 789 } reason "Nedovoljna motivacija"')

    assert_equal :approval, ast[:type]
    assert_equal :reject, ast[:action]
    assert_equal :application, ast[:approval_type]
    assert_equal "Nedovoljna motivacija", ast[:reason]
  end

  # Execution tests - Proposals
  test "lists pending proposals" do
    result = Platform::DSL.execute('proposals { status: "pending" } | list')

    assert_equal :list_proposals, result[:action]
    assert result[:count] >= 1
    assert result[:proposals].any? { |p| p[:id] == @proposal.id }
  end

  test "shows proposal details" do
    result = Platform::DSL.execute("proposals { id: #{@proposal.id} } | show")

    assert_equal :show_proposal, result[:action]
    assert_equal @proposal.id, result[:id]
    assert_equal "pending", result[:status]
    assert_equal "update_content", result[:change_type]
    assert_equal @curator.username, result[:proposer][:username]
  end

  test "counts proposals by status" do
    result = Platform::DSL.execute('proposals | count')

    assert result[:pending] >= 1
    assert result[:total] >= 1
  end

  # Execution tests - Applications
  test "lists pending applications" do
    result = Platform::DSL.execute('applications { status: "pending" } | list')

    assert_equal :list_applications, result[:action]
    assert result[:count] >= 1
    assert result[:applications].any? { |a| a[:id] == @application.id }
  end

  test "shows application details" do
    result = Platform::DSL.execute("applications { id: #{@application.id} } | show")

    assert_equal :show_application, result[:action]
    assert_equal @application.id, result[:id]
    assert_equal "pending", result[:status]
    assert_equal @regular_user.username, result[:user][:username]
    assert_includes result[:motivation], "Želim doprinijeti"
  end

  # Execution tests - Approve proposal
  test "approves pending proposal" do
    result = Platform::DSL.execute("approve proposal { id: #{@proposal.id} }")

    assert result[:success]
    assert_equal :approve_proposal, result[:action]
    assert_equal @proposal.id, result[:proposal_id]

    @proposal.reload
    assert @proposal.approved?

    # Verify changes were applied
    @location.reload
    assert_equal "Novi opis lokacije", @location.description
  end

  test "approves proposal with notes" do
    result = Platform::DSL.execute("approve proposal { id: #{@proposal.id} } notes \"Odlična izmjena\"")

    assert result[:success]
    assert_equal "Odlična izmjena", result[:notes]

    @proposal.reload
    assert_equal "Odlična izmjena", @proposal.admin_notes
  end

  test "rejects proposal with reason" do
    result = Platform::DSL.execute("reject proposal { id: #{@proposal.id} } reason \"Netačne informacije\"")

    assert result[:success]
    assert_equal :reject_proposal, result[:action]
    assert_equal "Netačne informacije", result[:reason]

    @proposal.reload
    assert @proposal.rejected?

    # Verify changes were NOT applied
    @location.reload
    assert_equal "Originalni opis", @location.description
  end

  test "rejects rejection without reason" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("reject proposal { id: #{@proposal.id} } reason \"\"")
    end

    assert_match(/razlog/i, error.message)
  end

  # Execution tests - Approve application
  test "approves curator application" do
    result = Platform::DSL.execute("approve application { id: #{@application.id} }")

    assert result[:success]
    assert_equal :approve_application, result[:action]
    assert_equal @application.id, result[:application_id]

    @application.reload
    assert @application.approved?

    # Verify user is now curator
    @regular_user.reload
    assert @regular_user.curator? || @regular_user.can_curate?
  end

  test "rejects curator application" do
    result = Platform::DSL.execute("reject application { id: #{@application.id} } reason \"Nedovoljna motivacija\"")

    assert result[:success]
    assert_equal :reject_application, result[:action]
    assert_equal "Nedovoljna motivacija", result[:reason]

    @application.reload
    assert @application.rejected?

    # Verify user is NOT curator
    @regular_user.reload
    refute @regular_user.curator?
  end

  # Error handling
  test "rejects approval for non-existent proposal" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("approve proposal { id: 999999 }")
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "rejects approval for non-existent application" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("approve application { id: 999999 }")
    end

    assert_match(/nije pronađena/i, error.message)
  end

  test "rejects approval for already approved proposal" do
    @proposal.update!(status: :approved)

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("approve proposal { id: #{@proposal.id} }")
    end

    assert_match(/pending/i, error.message)
  end

  test "rejects approval for already rejected application" do
    @application.update!(status: :rejected)

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("approve application { id: #{@application.id} }")
    end

    assert_match(/pending/i, error.message)
  end

  # Audit logging
  test "creates audit log for proposal approval" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("approve proposal { id: #{@proposal.id} }")
    end

    log = PlatformAuditLog.last
    assert_equal "approve", log.action
    assert_equal "ContentChange", log.record_type
    assert_equal "platform_dsl_approval", log.triggered_by
  end

  test "creates audit log for application rejection" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("reject application { id: #{@application.id} } reason \"Test razlog\"")
    end

    log = PlatformAuditLog.last
    assert_equal "reject", log.action
    assert_equal "CuratorApplication", log.record_type
    assert_equal "platform_dsl_approval", log.triggered_by
  end
end

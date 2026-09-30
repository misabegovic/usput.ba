# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ApprovalTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      email: "test_admin_#{SecureRandom.hex(4)}@example.com",
      user_type: :admin,
      password: "securepassword123"
    )

    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      email: "test_curator_#{SecureRandom.hex(4)}@example.com",
      user_type: :curator,
      password: "securepassword123"
    )

    @regular_user = User.create!(
      username: "test_user_#{SecureRandom.hex(4)}",
      email: "test_user_#{SecureRandom.hex(4)}@example.com",
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
  end

  # Parser tests - Proposals commands
  test "parses proposals list command" do
    ast = Platform::DSL::Parser.parse('proposals { status: "pending" } | list')

    assert_equal :proposals_query, ast[:type]
    assert_equal "pending", ast[:filters][:status]
  end

  test "parses proposals show command" do
    ast = Platform::DSL::Parser.parse("proposals { id: 123 } | show")

    assert_equal :proposals_query, ast[:type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses proposals without filters" do
    ast = Platform::DSL::Parser.parse("proposals | list")

    assert_equal :proposals_query, ast[:type]
  end

  # Curator applications were removed with the curator area; an admin sets
  # roles in Avo instead.
  test "curator application commands are gone" do
    [ "approve application { id: 1 }", 'reject application { id: 1 } reason "x"' ].each do |dsl|
      assert_raises(Platform::DSL::ParseError, dsl) { Platform::DSL::Parser.parse(dsl) }
    end
    error = assert_raises(Platform::DSL::ExecutionError) { Platform::DSL.execute("applications | list") }
    assert_match "applications", error.message
  end

  # Parser tests - Approve commands
  test "parses approve proposal command" do
    ast = Platform::DSL::Parser.parse("approve proposal { id: 123 }")

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

  # Parser tests - Reject commands
  test "parses reject proposal command" do
    ast = Platform::DSL::Parser.parse('reject proposal { id: 123 } reason "Netačne informacije"')

    assert_equal :approval, ast[:type]
    assert_equal :reject, ast[:action]
    assert_equal :proposal, ast[:approval_type]
    assert_equal "Netačne informacije", ast[:reason]
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
    result = Platform::DSL.execute("proposals | count")

    assert result[:pending] >= 1
    assert result[:total] >= 1
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

  # Error handling
  test "rejects approval for non-existent proposal" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("approve proposal { id: 999999 }")
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "rejects approval for already approved proposal" do
    @proposal.update!(status: :approved)

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("approve proposal { id: #{@proposal.id} }")
    end

    assert_match(/pending/i, error.message)
  end
end

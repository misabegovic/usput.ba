# frozen_string_literal: true

require "test_helper"

class Usput::CLITest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(username: "cli_curator", email: "cli_curator@example.com", password: "password123",
                            user_type: :curator).tap(&:confirm)
    @place = Location.create!(name: "Prokoško jezero", city: "Fojnica", lat: 43.9500, lng: 17.9500)
  end

  test "help lists every command" do
    status, out, = cli("help")

    assert_equal 0, status
    Usput::Commands.all.each { |command| assert_includes out, command.command_name.tr(".", " ") }
  end

  test "a list prints a table for people and JSON for agents" do
    _, table, = cli("places", "list", "city=Fojnica")
    _, json, = cli("places", "list", "city=Fojnica", "--json")

    assert_match(/^id\s+name\s+city/, table)
    assert_includes table, "Prokoško jezero"
    assert_equal [ @place.uuid ], JSON.parse(json).pluck("id")
  end

  test "bare values fill the required parameters in order" do
    _, out, = cli("places", "show", @place.uuid)
    assert_includes out, "name: Prokoško jezero"

    Decisions.archive(@place, by: @curator)
    status, out, = cli("history", "place", @place.uuid, "--as", @curator.email)
    assert_equal 0, status
    assert_includes out, "PlaceArchived"
  end

  test "a decision needs --as, and a refusal exits 1" do
    status, _, err = cli("places", "archive", @place.uuid)
    assert_equal 1, status
    assert_match(/not allowed/, err)

    status, = cli("places", "archive", @place.uuid, "--as", @curator.email)
    assert_equal 0, status
    assert @place.reload.archived?
  end

  test "an unknown command exits 2" do
    status, _, err = cli("castles", "list")

    assert_equal 2, status
    assert_match(/No command castles list/, err)
  end

  test "tokens issue prints a token that authenticates once copied" do
    status, out, = cli("tokens", "issue", @curator.email, "laptop")

    assert_equal 0, status
    token = out.lines.last.strip
    assert_equal @curator, APIToken.authenticate(token).user
  end

  private

  def cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Usput::CLI.new(argv, out:, err:).run
    [ status, out.string, err.string ]
  end
end

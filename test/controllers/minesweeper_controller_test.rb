require "test_helper"
require_relative "../support/mine_checker_fixtures"

class MinesweeperControllerTest < ActionDispatch::IntegrationTest
  test "show renders with the fictional-game disclaimer" do
    get minesweeper_path
    assert_response :success
    assert_match I18n.t("minesweeper.disclaimer_title"), response.body
    assert_match I18n.t("minesweeper.disclaimer"), response.body
    assert_match "bhmac.org", response.body
  end

  test "every region renders" do
    MinesweeperController::REGIONS.each_key do |slug|
      get minesweeper_path(region: slug)
      assert_response :success, "region #{slug} failed"
    end
  end

  test "every difficulty renders with region-scaled board values" do
    region = MinesweeperController::REGIONS["sarajevo"]
    MinesweeperController::DIFFICULTIES.each do |level, config|
      get minesweeper_path(level: level)
      assert_response :success, "level #{level} failed"
      expected = MinesweeperController.mines_for(config, region)
      assert_match "data-minesweeper-mines-value=\"#{expected}\"", response.body
    end
  end

  test "mine density mirrors real regional statistics" do
    easy = MinesweeperController::DIFFICULTIES["easy"]
    sarajevo = MinesweeperController.mines_for(easy, MinesweeperController::REGIONS["sarajevo"])
    sutjeska = MinesweeperController.mines_for(easy, MinesweeperController::REGIONS["sutjeska"])
    assert_operator sarajevo, :>, sutjeska,
                    "the most-contaminated region must have more mines than the least-contaminated"
    MinesweeperController::REGIONS.each_value do |region|
      MinesweeperController::DIFFICULTIES.each_value do |config|
        mines = MinesweeperController.mines_for(config, region)
        assert_operator mines, :>=, 5
        assert_operator mines, :<=, config[:rows] * config[:cols] * 3 / 10
      end
    end
  end

  test "show renders the density note and real aggregate facts" do
    get minesweeper_path(region: "jajce")
    assert_response :success
    assert_match I18n.t("minesweeper.density_note", name: "Jajce", km2: 62), response.body
    assert_match "BH Mine Suspected Areas", response.body
  end

  test "custom point near a real suspected area renders a scaled board" do
    points = MineCheckerFixtures.install!
    get minesweeper_path(lat: points[:inside][:lat], lon: points[:inside][:lon])
    assert_response :success
    assert_match I18n.t("minesweeper.custom_location"), response.body
    assert_match "data-minesweeper-mines-value=", response.body
  end

  test "custom point with no recorded areas nearby is not playable" do
    points = MineCheckerFixtures.install!
    get minesweeper_path(lat: points[:clear][:lat], lon: points[:clear][:lon])
    assert_response :success
    assert_match I18n.t("minesweeper.not_suspicious"), response.body
    refute_match "data-minesweeper-mines-value=", response.body
  end

  test "custom point outside BiH redirects to the default board" do
    get minesweeper_path(lat: 48.2, lon: 16.4)
    assert_redirected_to minesweeper_path
  end

  # Region boards use baked-in aggregates; only custom-point boards run the
  # single documented 5 km aggregate query.
  test "show never queries mine tables" do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] if payload[:sql] =~ /mine_areas|mine_check_audits/i
    end
    get minesweeper_path
    assert_response :success
    assert_empty queries, "the public game page must not touch mine data at runtime"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "unknown region redirects to the default board" do
    get minesweeper_path(region: "atlantida")
    assert_redirected_to minesweeper_path
  end

  test "unknown level falls back to easy" do
    get minesweeper_path(level: "nightmare")
    assert_response :success
    expected = MinesweeperController.mines_for(
      MinesweeperController::DIFFICULTIES["easy"], MinesweeperController::REGIONS["sarajevo"]
    )
    assert_match "data-minesweeper-mines-value=\"#{expected}\"", response.body
  end
end

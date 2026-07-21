require "test_helper"
require_relative "../support/mine_checker_fixtures"

# Educational minesweeper: geographic board, mine cells derived from the
# recorded suspected areas, playable only where the data records something.
class MinesweeperControllerTest < ActionDispatch::IntegrationTest
  test "board at an affected location derives mine cells from real data" do
    points = MineCheckerFixtures.install!
    get minesweeper_path(lat: points[:inside][:lat], lon: points[:inside][:lon])
    assert_response :success
    mines_attr = response.body[/data-minesweeper-mines-value="([^"]*)"/, 1]
    assert mines_attr.present?, "board must embed its mine cells"
    mines = JSON.parse(CGI.unescape_html(mines_attr))
    assert mines.any?, "a board centered inside a suspected area must contain mine cells"
    assert_match I18n.t("minesweeper.disclaimer_title"), response.body
    assert_match "bhmac.org", response.body
  end

  test "board with no recorded areas is not playable" do
    points = MineCheckerFixtures.install!
    get minesweeper_path(lat: points[:clear][:lat], lon: points[:clear][:lon])
    assert_response :success
    assert_match I18n.t("minesweeper.not_suspicious"), response.body
    refute_match "data-minesweeper-mines-value", response.body
  end

  test "every region renders" do
    MinesweeperController::REGIONS.each_key do |slug|
      get minesweeper_path(region: slug)
      assert_response :success, "region #{slug} failed"
    end
  end

  test "every difficulty renders" do
    points = MineCheckerFixtures.install!
    MinesweeperController::DIFFICULTIES.each_key do |level|
      get minesweeper_path(lat: points[:inside][:lat], lon: points[:inside][:lon], level: level)
      assert_response :success, "level #{level} failed"
    end
  end

  test "unknown region redirects to the default board" do
    get minesweeper_path(region: "atlantida")
    assert_redirected_to minesweeper_path
  end

  test "custom point outside BiH redirects to the default board" do
    get minesweeper_path(lat: 48.2, lon: 16.4)
    assert_redirected_to minesweeper_path
  end
end

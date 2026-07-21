require "test_helper"

class MinolovacControllerTest < ActionDispatch::IntegrationTest
  test "show renders with the fictional-game disclaimer" do
    get minolovac_path
    assert_response :success
    assert_match I18n.t("minolovac.disclaimer_title"), response.body
    assert_match I18n.t("minolovac.disclaimer"), response.body
    assert_match "bhmac.org", response.body
  end

  test "every region renders" do
    MinolovacController::REGIONS.each_key do |slug|
      get minolovac_path(region: slug)
      assert_response :success, "region #{slug} failed"
    end
  end

  test "every difficulty renders with region-scaled board values" do
    region = MinolovacController::REGIONS["sarajevo"]
    MinolovacController::DIFFICULTIES.each do |level, config|
      get minolovac_path(level: level)
      assert_response :success, "level #{level} failed"
      expected = MinolovacController.mines_for(config, region)
      assert_match "data-minolovac-mines-value=\"#{expected}\"", response.body
    end
  end

  test "mine density mirrors real regional statistics" do
    easy = MinolovacController::DIFFICULTIES["easy"]
    sarajevo = MinolovacController.mines_for(easy, MinolovacController::REGIONS["sarajevo"])
    sutjeska = MinolovacController.mines_for(easy, MinolovacController::REGIONS["sutjeska"])
    assert_operator sarajevo, :>, sutjeska,
                    "the most-contaminated region must have more mines than the least-contaminated"
    MinolovacController::REGIONS.each_value do |region|
      MinolovacController::DIFFICULTIES.each_value do |config|
        mines = MinolovacController.mines_for(config, region)
        assert_operator mines, :>=, 5
        assert_operator mines, :<=, config[:rows] * config[:cols] * 3 / 10
      end
    end
  end

  test "show renders the density note and real aggregate facts" do
    get minolovac_path(region: "jajce")
    assert_response :success
    assert_match I18n.t("minolovac.density_note", name: "Jajce", km2: 62), response.body
    assert_match "BH Mine Suspected Areas", response.body
  end

  test "custom point inside BiH renders a scaled board with local statistics" do
    get minolovac_path(lat: 43.8563, lon: 18.4131)
    assert_response :success
    assert_match I18n.t("minolovac.custom_location"), response.body
    assert_match "data-minolovac-mines-value=", response.body
  end

  test "custom point outside BiH redirects to the default board" do
    get minolovac_path(lat: 48.2, lon: 16.4)
    assert_redirected_to minolovac_path
  end

  # Region boards use baked-in aggregates; only custom-point boards run the
  # single documented 5 km aggregate query.
  test "show never queries mine tables" do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] if payload[:sql] =~ /mine_areas|mine_check_audits/i
    end
    get minolovac_path
    assert_response :success
    assert_empty queries, "the public game page must not touch mine data at runtime"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "unknown region redirects to the default board" do
    get minolovac_path(region: "atlantida")
    assert_redirected_to minolovac_path
  end

  test "unknown level falls back to easy" do
    get minolovac_path(level: "nightmare")
    assert_response :success
    expected = MinolovacController.mines_for(
      MinolovacController::DIFFICULTIES["easy"], MinolovacController::REGIONS["sarajevo"]
    )
    assert_match "data-minolovac-mines-value=\"#{expected}\"", response.body
  end

  test "map is not found without an api key" do
    original = Rails.application.config.geoapify.api_key
    Rails.application.config.geoapify.api_key = nil
    get minolovac_map_path(region: "sarajevo")
    assert_response :not_found
  ensure
    Rails.application.config.geoapify.api_key = original
  end

  test "map with unknown region is not found" do
    get minolovac_map_path(region: "atlantida")
    assert_response :not_found
  end
end

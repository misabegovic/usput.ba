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

  test "every difficulty renders with matching board values" do
    MinolovacController::DIFFICULTIES.each do |level, config|
      get minolovac_path(level: level)
      assert_response :success, "level #{level} failed"
      assert_match "data-minolovac-mines-value=\"#{config[:mines]}\"", response.body
    end
  end

  test "unknown region redirects to the default board" do
    get minolovac_path(region: "atlantida")
    assert_redirected_to minolovac_path
  end

  test "unknown level falls back to easy" do
    get minolovac_path(level: "nightmare")
    assert_response :success
    assert_match "data-minolovac-mines-value=\"#{MinolovacController::DIFFICULTIES['easy'][:mines]}\"", response.body
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

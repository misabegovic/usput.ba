# frozen_string_literal: true

require "test_helper"

# Usput works from iOS 15.4 and Chrome 99 (wiki/decisions/support-phones-from-ios-15.md).
class BrowserFloorTest < ActionDispatch::IntegrationTest
  test "every layout loads the import map shim before the import map" do
    sign_in User.create!(username: "floor_curator", email: "floor_curator@example.com",
                         password: "password123", user_type: :curator).tap(&:confirm)

    { "/" => "new_design", "/mine-check" => "application", "/curator" => "curator" }.each do |path, layout|
      get path
      assert_response :success, "#{path} (#{layout} layout)"

      shim = response.body.index(%r{<script[^>]+src="/assets/es-module-shims-[^"]+\.js"[^>]*async})
      importmap = response.body.index('<script type="importmap"')
      assert shim, "#{layout}: es-module-shims is loaded, async"
      assert shim < importmap, "#{layout}: the shim comes before the import map"
    end
  end

  test "the old-browser notice starts hidden and a no-JavaScript notice is there" do
    get "/"

    assert_select "p#browser-floor-notice[hidden][role=alert]", text: I18n.t("browser_floor.outdated", locale: :en)
    assert_select "noscript p", text: I18n.t("browser_floor.no_javascript", locale: :en)
  end

  test "the policy lets the shim run the modules it rewrites" do
    get "/"

    assert_match(/script-src[^;]*\bblob:/, response.headers["Content-Security-Policy"])
  end
end

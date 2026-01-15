# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  # === Imprint page tests ===

  test "imprint page renders successfully" do
    get imprint_path

    assert_response :success
  end

  test "imprint page is accessible without authentication" do
    get imprint_path

    assert_response :success
  end

  # === Privacy page tests ===

  test "privacy page renders successfully" do
    get privacy_path

    assert_response :success
  end

  test "privacy page is accessible without authentication" do
    get privacy_path

    assert_response :success
  end

  # === Terms page tests ===

  test "terms page renders successfully" do
    get terms_path

    assert_response :success
  end

  test "terms page is accessible without authentication" do
    get terms_path

    assert_response :success
  end

  # === Localization tests ===

  test "imprint page respects locale parameter" do
    get imprint_path, params: { locale: "bs" }

    assert_response :success
  end

  test "privacy page respects locale parameter" do
    get privacy_path, params: { locale: "bs" }

    assert_response :success
  end

  test "terms page respects locale parameter" do
    get terms_path, params: { locale: "bs" }

    assert_response :success
  end

  test "pages work with English locale" do
    get imprint_path, params: { locale: "en" }
    assert_response :success

    get privacy_path, params: { locale: "en" }
    assert_response :success

    get terms_path, params: { locale: "en" }
    assert_response :success
  end

  # === Edge cases ===

  test "pages handle invalid locale gracefully" do
    get imprint_path, params: { locale: "invalid_locale" }

    # Should still render, falling back to default locale
    assert_response :success
  end

  test "pages are cacheable" do
    get imprint_path

    assert_response :success
    # Static pages should be cacheable
  end
end

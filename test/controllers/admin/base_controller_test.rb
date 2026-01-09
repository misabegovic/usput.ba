# frozen_string_literal: true

require "test_helper"

class Admin::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ADMIN_DASHBOARD"] = "true"
    ENV["ADMIN_USERNAME"] = "testadmin"
    ENV["ADMIN_PASSWORD"] = "testpass123"
    Flipper.enable(:admin_dashboard)
  end

  teardown do
    ENV["ADMIN_DASHBOARD"] = nil
    ENV["ADMIN_USERNAME"] = nil
    ENV["ADMIN_PASSWORD"] = nil
    Flipper.disable(:admin_dashboard)
  end

  test "admin dashboard requires login" do
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "admin dashboard accessible after login" do
    login_as_admin
    get admin_root_path
    assert_response :success
  end

  test "admin dashboard disabled when ENV is false" do
    ENV["ADMIN_DASHBOARD"] = "false"
    login_as_admin
    get admin_root_path
    assert_redirected_to root_path
  end

  test "admin dashboard disabled when Flipper flag is off" do
    Flipper.disable(:admin_dashboard)
    login_as_admin
    get admin_root_path
    assert_redirected_to root_path
  end

  private

  def login_as_admin
    post admin_login_path, params: {
      username: "testadmin",
      password: "testpass123"
    }
  end
end

# frozen_string_literal: true

require "test_helper"

class AdminGateTest < ActionDispatch::IntegrationTest
  test "a guest is sent to sign in" do
    get "/admin"

    assert_redirected_to "/login"
  end

  test "a traveller finds no admin" do
    sign_in user(:basic)

    get "/admin"

    assert_response :not_found
  end

  test "a curator is let in" do
    sign_in user(:curator)

    get "/admin"
    follow_redirect! while response.redirect?

    assert_response :success
  end

  test "an admin is let in" do
    sign_in user(:admin)

    get "/admin"
    follow_redirect! while response.redirect?

    assert_response :success
  end

  test "a blocked curator is signed out at the door" do
    curator = user(:curator)
    sign_in curator
    curator.block!

    get "/admin"

    assert_redirected_to "/login"
  end

  test "Avo turns a traveller away on its own, even past the route" do
    assert_nil run_avo_gate(user(:curator)), "a curator passes"
    assert_equal "/", run_avo_gate(user(:basic)), "a traveller is sent home"
    assert_equal "/", run_avo_gate(nil), "nobody signed in is sent home"
  end

  test "the admin opens on its welcome page" do
    sign_in user(:admin)

    get "/admin"

    assert_redirected_to "/admin/welcome"
    follow_redirect!
    assert_includes response.body, I18n.t("admin.welcome.role_admin")
  end

  private

  # Runs Avo's own sign-in check against a stand-in controller and returns where
  # it redirected, or nil when it let the user through.
  def run_avo_gate(user)
    controller = Class.new do
      attr_reader :redirected_to

      def initialize(user) = @user = user
      def current_user = @user
      def main_app = Rails.application.routes.url_helpers
      def t(key) = key
      def redirect_to(path, **) = @redirected_to = path
    end.new(user)
    controller.instance_eval(&Avo.configuration.authenticate)
    controller.redirected_to
  end

  def user(role)
    User.create!(username: "gate_#{role}", email: "gate_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

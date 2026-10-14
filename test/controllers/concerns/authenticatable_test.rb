# frozen_string_literal: true

require "test_helper"

# A probe controller behind each filter, so the concern is tested without
# borrowing a real page that may move or go.
class AuthenticatableProbeController < ApplicationController
  before_action :require_login
  before_action :require_curator, only: :curated

  def signed_in = render(plain: current_user.username)
  def curated = render(plain: "curated")
end

class AuthenticatableTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "test_user_#{SecureRandom.hex(4)}",
      email: "test_user_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      user_type: :basic
    )
    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      email: "test_curator_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      email: "test_admin_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      user_type: :admin
    )
  end

  test "a guest is sent to sign in" do
    with_probe_routes do
      get "/probe/signed_in"

      assert_redirected_to new_user_session_path
      assert_equal I18n.t("auth.login_required"), flash[:alert]
    end
  end

  test "require_login returns JSON error for API requests" do
    with_probe_routes do
      get "/probe/signed_in", headers: { "Accept" => "application/json" }

      assert_response :unauthorized
      assert_equal "Unauthorized", response.parsed_body["error"]
    end
  end

  test "a signed-in traveller is current_user" do
    with_probe_routes do
      sign_in_as @user
      get "/probe/signed_in"

      assert_response :success
      assert_equal @user.username, response.body
    end
  end

  test "signing out clears the session" do
    with_probe_routes do
      sign_in_as @user
      delete destroy_user_session_path
      get "/probe/signed_in"

      assert_redirected_to new_user_session_path
    end
  end

  test "require_curator redirects regular users" do
    with_probe_routes do
      sign_in_as @user
      get "/probe/curated"

      assert_redirected_to root_path
      assert_equal I18n.t("auth.curator_required"), flash[:alert]
    end
  end

  test "require_curator allows curators and admins" do
    with_probe_routes do
      [ @curator, @admin ].each do |person|
        sign_in_as person
        get "/probe/curated"

        assert_response :success, "#{person.user_type} should pass"
        delete destroy_user_session_path
      end
    end
  end

  test "require_curator returns JSON forbidden for API requests" do
    with_probe_routes do
      sign_in_as @user
      get "/probe/curated", headers: { "Accept" => "application/json" }

      assert_response :forbidden
      assert_equal "Forbidden", response.parsed_body["error"]
    end
  end

  private

  def with_probe_routes(&)
    with_routing do |set|
      set.draw do
        devise_for :users, path: "", controllers: { sessions: "users/sessions" },
                           path_names: { sign_in: "login", sign_out: "logout" }
        get "probe/signed_in", to: "authenticatable_probe#signed_in"
        get "probe/curated", to: "authenticatable_probe#curated"
        root "new_design#home"
      end
      yield
    end
  end

  def sign_in_as(person)
    post user_session_path, params: { user: { email: person.email, password: "password123" } }
  end
end

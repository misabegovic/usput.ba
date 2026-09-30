# frozen_string_literal: true

require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = person(:admin)
    @curator = person(:curator)
    @traveller = person(:basic)
  end

  test "an admin lists users and finds one by name or email" do
    sign_in @admin

    get "/admin/resources/users", params: { q: "admin_users_basic" }

    assert_response :success
    assert_includes response.body, @traveller.email
  end

  test "a curator cannot open users, nor one user, nor the edit form" do
    sign_in @curator

    [ "/admin/resources/users", "/admin/resources/users/#{@traveller.to_param}", "/admin/resources/users/#{@traveller.to_param}/edit" ].each do |path|
      get path
      assert_not response.successful?, "#{path} should be refused to a curator"
    end
  end

  test "a curator cannot change a user through the form either" do
    sign_in @curator

    patch "/admin/resources/users/#{@traveller.to_param}", params: { user: { username: "renamed" } }

    assert_equal "admin_users_basic", @traveller.reload.username
  end

  test "users do not appear in a curator's menu" do
    sign_in @curator

    get "/admin/welcome"

    assert_response :success
    assert_select "a[href='/admin/resources/users']", count: 0
  end

  test "users appear in an admin's menu" do
    sign_in @admin

    get "/admin/welcome"

    assert_select "a[href='/admin/resources/users']"
  end

  test "an admin blocks a traveller, who is signed out" do
    other = open_session
    other.post user_session_path, params: { user: { email: @traveller.email, password: "password123" } }
    sign_in @admin

    run_action "block_user", @traveller

    assert @traveller.reload.blocked?
    other.get user_plans_path, as: :json
    assert_equal 401, other.response.status
  end

  test "an admin cannot block themselves" do
    sign_in @admin

    run_action "block_user", @admin

    assert_not @admin.reload.blocked?
  end

  test "an admin unblocks a blocked account" do
    @traveller.block!
    sign_in @admin

    run_action "unblock_user", @traveller

    assert_not @traveller.reload.blocked?
  end

  test "an admin promotes a traveller to curator" do
    sign_in @admin

    run_action "change_role", @traveller, fields: { role: "curator" }

    assert @traveller.reload.curator?
  end

  test "an admin opens a user's page by its public id" do
    sign_in @admin

    get "/admin/resources/users/#{@traveller.to_param}"

    assert_response :success
    assert_includes response.body, @traveller.email
  end

  test "a curator cannot run the users actions" do
    sign_in @curator

    run_action "block_user", @traveller

    assert_not @traveller.reload.blocked?
  end

  private

  def run_action(action, user, fields: {})
    post "/admin/resources/users/actions/Avo::Actions::#{action.camelize}",
      params: { fields: fields.merge(avo_resource_ids: user.to_param, avo_selected_all: "false") },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def person(role)
    User.create!(username: "admin_users_#{role}", email: "admin_users_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

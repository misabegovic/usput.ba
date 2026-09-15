# frozen_string_literal: true

require "test_helper"

# The desktop bar and the mobile menu are written separately. Moments once
# reached only the desktop one, so the moderation queue was unreachable on a
# phone and nothing failed.
class Curator::NavTest < ActionDispatch::IntegrationTest
  setup do
    @curator = User.create!(username: "nav_curator", password: "password123", user_type: :curator)
  end

  teardown do
    @curator&.destroy
  end

  test "workflow routes are linked from both navs" do
    login_as(@curator)
    get curator_root_path

    assert_response :success
    nav = response.body[/<nav\b.*?<\/nav>/m]

    [ curator_reviews_path, curator_proposals_path, curator_moments_path ].each do |path|
      count = nav.scan(/href="#{Regexp.escape(path)}"/).size
      assert_equal 2, count, "#{path} should be in the desktop nav and the mobile nav, found #{count}"
    end
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end

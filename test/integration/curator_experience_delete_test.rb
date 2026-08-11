# frozen_string_literal: true

require "test_helper"

# Deleting an experience is a two-step workflow: a curator files a proposal, an
# admin approves it. The whole chain worked long before there was a button to
# start it — the delete was reachable only by hand-crafting an HTTP request —
# so these tests pin the affordance, not just the mechanism.
class CuratorExperienceDeleteTest < ActionDispatch::IntegrationTest
  setup do
    @curator = User.create!(username: "del_curator", password: "password123", user_type: :curator)
    @admin = User.create!(username: "del_admin", password: "password123", user_type: :admin)
    @experience = Experience.create!(title: "Doomed Experience", description: "d")
    Flipper.enable(:curator_edit_delete)
  end

  teardown do
    ContentChange.destroy_all
    @experience&.destroy if @experience&.persisted?
    @curator&.destroy
    @admin&.destroy
  end

  test "the show page offers a delete button when the flag is on" do
    login_as(@curator)

    get curator_experience_path(@experience)

    assert_response :success
    assert_select "form[action=?][method=post]", curator_experience_path(@experience) do
      assert_select "input[name='_method'][value='delete']"
    end
  end

  test "the delete button is hidden when the flag is off" do
    Flipper.disable(:curator_edit_delete)
    login_as(@curator)

    get curator_experience_path(@experience)

    assert_response :success
    assert_select "input[name='_method'][value='delete']", count: 0
  end

  test "a curator's delete files a proposal rather than destroying the experience" do
    login_as(@curator)

    assert_no_difference "Experience.count" do
      delete curator_experience_path(@experience)
    end

    proposal = ContentChange.find_by(changeable: @experience, change_type: :delete_content)
    assert proposal.present?
    assert proposal.pending?
    assert_equal @curator, proposal.user
  end

  test "an admin approving the proposal destroys the experience" do
    login_as(@curator)
    delete curator_experience_path(@experience)
    proposal = ContentChange.find_by(changeable: @experience, change_type: :delete_content)
    delete logout_path

    login_as(@admin)

    assert_difference "Experience.count", -1 do
      post approve_curator_admin_content_change_path(proposal)
    end

    assert proposal.reload.approved?
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end

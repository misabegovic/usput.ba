# frozen_string_literal: true

require "test_helper"

# Proposals are gone: curators edit places, experiences, plans and audio tours
# directly in the admin, so the old curator pages for them are gone too.
class CuratorProposalsRemovedTest < ActionDispatch::IntegrationTest
  setup do
    @curator = person(:curator)
    @place = Location.create!(name: "Kravice", city: "Ljubuški", lat: 43.1564, lng: 17.6081)
  end

  test "the old curator content pages are not routed" do
    %w[/curator/locations /curator/experiences /curator/plans /curator/audio_tours /curator/proposals
       /curator/admin/content_changes /curator/locations/needs_photos].each do |path|
      assert_raises(ActionController::RoutingError, path) { Rails.application.routes.recognize_path(path) }
    end
  end

  test "the proposal tables are gone" do
    %w[content_changes content_change_contributions curator_reviews].each do |table|
      assert_not ActiveRecord::Base.connection.table_exists?(table), "#{table} should be dropped"
    end
  end

  test "the curator dashboard sends content work to the admin" do
    sign_in @curator

    get curator_root_path

    assert_response :success
    assert_select "a[href=?]", "/admin/resources/locations/new"
    assert_select "a[href=?]", "/admin/resources/audio_tours/new"
  end

  test "a place's edit button opens it in the admin" do
    sign_in @curator

    get location_path(@place)

    assert_select "a[href=?]", "/admin/resources/locations/#{@place.to_param}/edit"
  end

  test "a curator cannot remove a review" do
    review = Review.create!(reviewable: @place, rating: 4, author_name: "Ana", comment: "Lijepo")
    sign_in @curator

    delete curator_review_path(review)

    assert Review.exists?(review.id)
  end

  test "an admin removes a review directly" do
    review = Review.create!(reviewable: @place, rating: 4, author_name: "Ana", comment: "Lijepo")
    sign_in person(:admin)

    delete curator_review_path(review)

    assert_redirected_to curator_reviews_path
    assert_not Review.exists?(review.id)
  end

  private

  def person(role)
    User.create!(username: "cpr_#{role}", email: "cpr_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

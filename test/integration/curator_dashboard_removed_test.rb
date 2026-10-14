# frozen_string_literal: true

require "test_helper"

# The curator dashboard is gone: curators edit places, experiences, plans and
# audio tours and decide moments and reviews in the admin, so no page of the old
# dashboard is left, nor the tables only it used.
class CuratorDashboardRemovedTest < ActionDispatch::IntegrationTest
  setup do
    @curator = person(:curator)
    @place = Location.create!(name: "Kravice", city: "Ljubuški", lat: 43.1564, lng: 17.6081)
  end

  test "no route begins with /curator" do
    curator_routes = Rails.application.routes.routes.map { |route| route.path.spec.to_s }.grep(%r{\A/curator})

    assert_empty curator_routes
  end

  test "the tables only the dashboard used are gone" do
    %w[content_changes content_change_contributions curator_reviews curator_activities
       flipper_features flipper_gates].each do |table|
      assert_not ActiveRecord::Base.connection.table_exists?(table), "#{table} should be dropped"
    end
  end

  test "a place's edit button opens it in the admin" do
    sign_in @curator

    get location_path(@place)

    assert_select "a[href=?]", "/admin/resources/locations/#{@place.to_param}/edit"
  end

  private

  def person(role)
    User.create!(username: "cpr_#{role}", email: "cpr_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

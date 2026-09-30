# frozen_string_literal: true

require "test_helper"

class AdminLocationsTest < ActionDispatch::IntegrationTest
  setup do
    @curator = person(:curator)
    @admin = person(:admin)
    @place = Location.create!(name: "Stari most", city: "Mostar", lat: 43.3372, lng: 17.8150)
  end

  test "a curator lists places and finds one by name" do
    sign_in @curator

    get "/admin/resources/locations", params: { q: "Stari" }

    assert_response :success
    assert_includes response.body, "Stari most"
  end

  test "the edit form has a tab for every language" do
    sign_in @curator

    get "/admin/resources/locations/#{@place.to_param}/edit"

    assert_response :success
    Translation::SUPPORTED_LOCALES.each do |locale|
      assert_select "[name='location[name_#{locale}]']", 1, "a name field for #{locale}"
    end
  end

  test "a curator creates a place with its translations, marked as hand-edited" do
    sign_in @curator

    assert_difference "Location.count", 1 do
      post "/admin/resources/locations", params: { location: { name: "Kravica", city: "Ljubuški", name_bs: "Kravica", name_de: "Kravica-Wasserfälle" } }
    end

    place = Location.find_by!(name: "Kravica")
    assert_equal "Kravica-Wasserfälle", place.name_de
    assert Translation.find_by(translatable: place, locale: "de", field_name: "name").human_edited_at.present?
  end

  test "a curator edits a translation and the other languages stay as they were" do
    @place.update!(name_en: "Old Bridge", name_de: "Alte Brücke")
    sign_in @curator

    patch "/admin/resources/locations/#{@place.to_param}", params: { location: { name_de: "Die Alte Brücke", name_en: "Old Bridge" } }

    @place.reload
    assert_equal "Die Alte Brücke", @place.name_de
    assert_nil Translation.find_by(translatable: @place, locale: "en", field_name: "name").human_edited_at
    assert Translation.find_by(translatable: @place, locale: "de", field_name: "name").human_edited_at.present?
  end

  test "a place inside a mine-suspected area is refused and nothing is saved" do
    point = StaticArtifacts::POINTS[:inside]
    sign_in @curator

    patch "/admin/resources/locations/#{@place.to_param}", params: { location: { lat: point[:lat], lng: point[:lon], name_de: "Neu" } }

    assert_not response.redirect?, "the form comes back with the error"
    assert_includes response.body, I18n.t("mine_check.blocked", data_as_of: "").split("%").first.strip[0, 20]
    assert_nil @place.reload.name_de
    assert_in_delta 43.3372, @place.lat.to_f, 0.0001
  end

  test "a curator cannot delete a place" do
    sign_in @curator

    delete "/admin/resources/locations/#{@place.to_param}"

    assert Location.exists?(@place.id)
  end

  test "an admin deletes a place nobody has visited" do
    sign_in @admin

    delete "/admin/resources/locations/#{@place.to_param}"

    assert_not Location.exists?(@place.id)
  end

  test "a curator archives and restores a place" do
    sign_in @curator

    run_action "ArchiveLocation", @place
    assert @place.reload.archived?

    run_action "RestoreLocation", @place
    assert_not @place.reload.archived?
  end

  test "archived places are hidden from the list until asked for" do
    @place.archive!
    sign_in @curator

    get "/admin/resources/locations"
    assert_not_includes response.body, "Stari most"
  end

  private

  def run_action(action, place)
    post "/admin/resources/locations/actions/Avo::Actions::#{action}",
      params: { fields: { avo_resource_ids: place.to_param, avo_selected_all: "false" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def person(role)
    User.create!(username: "admin_places_#{role}", email: "admin_places_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

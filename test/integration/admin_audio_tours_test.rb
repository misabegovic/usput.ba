# frozen_string_literal: true

require "test_helper"

class AdminAudioToursTest < ActionDispatch::IntegrationTest
  setup do
    @place = Location.create!(name: "Stari most", city: "Mostar", lat: 43.3372, lng: 17.8150)
    @tour = AudioTour.create!(location: @place, locale: "bs", script: "Most je sagrađen 1566.")
  end

  test "a curator lists audio tours by place" do
    sign_in person(:curator)

    get "/admin/resources/audio_tours"

    assert_response :success
    assert_includes response.body, "Stari most"
  end

  test "a curator adds a tour for another language" do
    sign_in person(:curator)

    assert_difference "AudioTour.count", 1 do
      post "/admin/resources/audio_tours",
        params: { audio_tour: { location_id: @place.to_param, locale: "en", script: "The bridge was built in 1566." } }
    end
    assert_equal "The bridge was built in 1566.", @place.audio_tours.find_by(locale: "en").script
  end

  test "a second tour in the same language is refused" do
    sign_in person(:curator)

    assert_no_difference "AudioTour.count" do
      post "/admin/resources/audio_tours", params: { audio_tour: { location_id: @place.to_param, locale: "bs", script: "x" } }
    end
  end

  test "a curator edits a script" do
    sign_in person(:curator)

    patch "/admin/resources/audio_tours/#{@tour.to_param}", params: { audio_tour: { script: "Novi tekst." } }

    assert_equal "Novi tekst.", @tour.reload.script
  end

  test "only an admin deletes a tour" do
    sign_in person(:curator)
    delete "/admin/resources/audio_tours/#{@tour.to_param}"
    assert AudioTour.exists?(@tour.id)

    sign_in person(:admin)
    delete "/admin/resources/audio_tours/#{@tour.to_param}"
    assert_not AudioTour.exists?(@tour.id)
  end

  private

  def person(role)
    User.create!(username: "aat_#{role}", email: "aat_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end

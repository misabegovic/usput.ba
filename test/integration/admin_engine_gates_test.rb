# frozen_string_literal: true

require "test_helper"

# Avo's attachments and search controllers sit outside the per-resource gate,
# and Avo Community's own authorization allows everything. The record's or
# the resource's policy decides there too.
class AdminEngineGatesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = person(:admin)
    @curator = person(:curator)
    @traveller = person(:basic)
    @traveller.avatar.attach(io: File.open("test/fixtures/files/real_image.jpg"), filename: "a.jpg", content_type: "image/jpeg")
    @place = Location.create!(name: "Kravice", city: "Ljubuški", lat: 43.1564, lng: 17.6081)
    @place.photos.attach(io: File.open("test/fixtures/files/real_image.jpg"), filename: "p.jpg", content_type: "image/jpeg")
  end

  test "a curator cannot delete a traveller's avatar" do
    sign_in @curator

    delete_attachment "users", @traveller, :avatar, @traveller.avatar.attachment

    assert @traveller.reload.avatar.attached?, "the avatar survives"
  end

  test "a curator cannot replace a traveller's avatar" do
    sign_in @curator
    before = @traveller.avatar.blob.id

    upload "users", @traveller, :avatar

    assert_equal before, @traveller.reload.avatar.blob.id, "the avatar is the traveller's own"
  end

  test "a curator can still change a place's photos" do
    sign_in @curator

    delete_attachment "locations", @place, :photos, @place.photos.first

    assert_not @place.reload.photos.attached?
  end

  test "an admin can delete a traveller's avatar" do
    sign_in @admin

    delete_attachment "users", @traveller, :avatar, @traveller.avatar.attachment

    assert_not @traveller.reload.avatar.attached?
  end

  test "a curator cannot search accounts by name or email" do
    sign_in @curator

    get "/admin/avo_api/users/search", params: { q: @traveller.email }

    assert_not_includes response.body, @traveller.email
    assert_not response.successful?
  end

  test "an admin can search accounts" do
    sign_in @admin

    get "/admin/avo_api/users/search", params: { q: "gates_basic" }

    assert_response :success
    assert_includes response.body, "gates_basic"
  end

  private

  def delete_attachment(resource, record, name, attachment)
    delete "/admin/resources/#{resource}/#{record.to_param}/active_storage_attachments/#{name}/#{attachment.id}",
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def upload(resource, record, name)
    post "/admin/avo_api/resources/#{resource}/#{record.to_param}/attachments",
         params: { attachment_key: name, filename: "x.jpg",
                   file: Rack::Test::UploadedFile.new("test/fixtures/files/real_image.jpg", "image/jpeg") }
  end

  def person(role)
    User.create!(username: "gates_#{role}", email: "gates_#{role}@example.com",
                 password: "password123", user_type: role).tap(&:confirm)
  end
end

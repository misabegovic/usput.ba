# frozen_string_literal: true

require "test_helper"

class CameraPhotoTest < ActiveSupport::TestCase
  test "a JPEG upload is passed through untouched" do
    upload = uploaded("already.jpg", "image/jpeg") { |path| write_jpeg(path) }

    assert_same upload, CameraPhoto.as_jpeg(upload)
  end

  test "a nil photo is not an error" do
    assert_nil CameraPhoto.as_jpeg(nil)
  end

  # A libvips without HEIF must degrade to the existing rejection, never a 500.
  test "an unconvertible upload is returned unchanged rather than raising" do
    upload = uploaded("broken.heic", "image/heic") { |path| File.write(path, "not an image") }

    assert_same upload, CameraPhoto.as_jpeg(upload)
  end

  private

  def uploaded(name, type)
    file = Tempfile.new([ File.basename(name, ".*"), File.extname(name) ])
    yield file.path
    ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: name, type: type)
  end

  def write_jpeg(path)
    Vips::Image.black(64, 64, bands: 3).add(200).cast(:uchar).write_to_file(path)
  end
end

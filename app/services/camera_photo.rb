# frozen_string_literal: true

# An iPhone shoots HEIC by default. Safari usually converts it on the way out of
# a file input, but not always — an Android sharing sheet, an in-app browser, or
# a file picked from another app can all arrive as HEIC. Moment only accepts
# JPEG, PNG, GIF and WebP, so without this the traveller takes a photo, is told
# it "must be JPEG, PNG, GIF, or WebP", and their only recourse is to go and
# change a camera setting. The upload is converted instead.
#
# It runs on the uploaded file rather than the attachment, because a blob
# attached to an unsaved record is not uploaded yet and cannot be read back.
class CameraPhoto
  FORMATS_NEEDING_CONVERSION = %w[image/heic image/heif].freeze

  def self.as_jpeg(upload)
    return upload unless upload.respond_to?(:content_type)
    return upload unless FORMATS_NEEDING_CONVERSION.include?(upload.content_type)

    jpeg = ImageProcessing::Vips.source(upload.tempfile.path).convert("jpg").call

    ActionDispatch::Http::UploadedFile.new(
      tempfile: jpeg,
      filename: "#{File.basename(upload.original_filename.to_s, '.*')}.jpg",
      type: "image/jpeg"
    )
  rescue StandardError => e
    # A libvips build without HEIF support raises here. The upload is passed
    # through unchanged and Moment#acceptable_photo rejects it with its own
    # message — degraded, not broken, and never a 500.
    Rails.logger.warn "[CameraPhoto] could not convert #{upload.content_type}: #{e.class}: #{e.message}"
    upload
  end
end

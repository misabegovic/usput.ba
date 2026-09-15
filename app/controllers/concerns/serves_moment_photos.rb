# frozen_string_literal: true

# Owner-path photo variants only: a public moment needs no session check.
module ServesMomentPhotos
  extend ActiveSupport::Concern

  # Looked up here rather than passed through, so a caller cannot make the
  # server process arbitrary variants on demand.
  PHOTO_VARIANTS = {
    "thumb" => { resize_to_fill: [ 200, 200 ] },
    "square" => { resize_to_fill: [ 600, 600 ] },
    "story" => { resize_to_limit: [ 1080, 1080 ] }
  }.freeze

  DEFAULT_PHOTO_VARIANT = "square"

  # Looked up like the variant: the caller names one rather than sending a header.
  DISPOSITIONS = { "attachment" => "attachment", "inline" => "inline" }.freeze

  private

  # A signed blob url is a bearer token Rails serves without a session check, so
  # we stream the bytes ourselves. `public:` decides shared-cache eligibility —
  # true only for already-public moments.
  def stream_moment_photo(moment, public:)
    return head :not_found unless moment.displayable?

    variant = moment.photo.variant(PHOTO_VARIANTS.fetch(params[:size], PHOTO_VARIANTS[DEFAULT_PHOTO_VARIANT])).processed
    expires_in 1.hour, public: public
    send_data variant.download,
              type: moment.photo.blob.content_type,
              filename: moment.photo.filename.to_s,
              disposition: DISPOSITIONS.fetch(params[:disposition], "inline")
  rescue Vips::Error, MiniMagick::Error => e
    Rails.logger.warn "[Moments] Unprocessable photo for moment #{params[:id]}: #{e.message}"
    head :unprocessable_entity
  # The blob can be deleted while its variant is being recorded — the moment was
  # removed under a request already in flight. That is a photo that is gone, not
  # a server that is broken.
  rescue ActiveRecord::InvalidForeignKey => e
    Rails.logger.warn "[Moments] Photo vanished mid-request for moment #{params[:id]}: #{e.message}"
    head :not_found
  end
end

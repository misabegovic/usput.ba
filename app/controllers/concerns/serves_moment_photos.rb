# frozen_string_literal: true

# Streams moment photo variants. Shared by the owner path (MomentsController)
# and the public path (Community::MomentsController): each resolves the moment
# its own way — ownership vs. public visibility — and hands an already-authorised
# one here, so the two trust models never mix in a single lookup.
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
              disposition: "inline"
  rescue Vips::Error, MiniMagick::Error => e
    Rails.logger.warn "[Moments] Unprocessable photo for moment #{params[:id]}: #{e.message}"
    head :unprocessable_entity
  end
end

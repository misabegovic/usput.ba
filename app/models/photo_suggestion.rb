# frozen_string_literal: true

# Allows curators to suggest photos for locations.
# Photos can be uploaded directly or provided via URL.
class PhotoSuggestion < ApplicationRecord
  belongs_to :user
  belongs_to :location
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_one_attached :photo do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 200]
  end

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :location, presence: true
  validates :description, length: { maximum: 1000 }
  validate :photo_or_url_present

  # Sanitize description
  before_save :sanitize_description

  scope :pending_review, -> { pending.order(created_at: :asc) }
  scope :for_location, ->(location) { where(location: location) }

  def approve!(admin, notes: nil)
    return false unless pending?

    transaction do
      if photo.attached?
        location.photos.attach(photo.blob)
      elsif photo_url.present?
        # Download and attach the photo from URL
        attach_photo_from_url!
      end

      update!(
        status: :approved,
        reviewed_by: admin,
        reviewed_at: Time.current,
        admin_notes: notes
      )
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to approve photo suggestion #{id}: #{e.message}"
    false
  end

  # Download photo from URL and attach to location
  def attach_photo_from_url!
    return unless photo_url.present?

    require "open-uri"
    require "tempfile"

    uri = URI.parse(photo_url)
    filename = File.basename(uri.path).presence || "photo_#{id}.jpg"

    # Ensure filename has an extension
    filename = "#{filename}.jpg" unless filename.match?(/\.(jpg|jpeg|png|gif|webp)$/i)

    downloaded_file = URI.open(photo_url, read_timeout: 30) # rubocop:disable Security/Open
    location.photos.attach(
      io: downloaded_file,
      filename: filename,
      content_type: downloaded_file.content_type || "image/jpeg"
    )
  rescue OpenURI::HTTPError, SocketError, Timeout::Error => e
    Rails.logger.error "Failed to download photo from URL #{photo_url}: #{e.message}"
    raise ActiveRecord::Rollback, "Failed to download photo from URL"
  end

  def reject!(admin, notes:)
    return false unless pending?

    update!(
      status: :rejected,
      reviewed_by: admin,
      reviewed_at: Time.current,
      admin_notes: notes
    )
  end

  def preview_url
    if photo.attached?
      Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true)
    else
      photo_url
    end
  end

  private

  def photo_or_url_present
    unless photo.attached? || photo_url.present?
      errors.add(:base, "Must provide either a photo file or a photo URL")
    end
  end

  def sanitize_description
    return if description.blank?

    self.description = ActionController::Base.helpers.sanitize(
      description,
      tags: %w[b i em strong br],
      attributes: []
    )
  end
end

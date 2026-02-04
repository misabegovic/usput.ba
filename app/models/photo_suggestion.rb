# frozen_string_literal: true

# Allows curators to suggest photos for locations.
# Photos can be uploaded directly or provided via URL.
class PhotoSuggestion < ApplicationRecord
  belongs_to :user
  belongs_to :location
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 200, 200 ]
  end

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :location, presence: true
  validates :description, length: { maximum: 1000 }
  validate :photos_or_url_present
  validate :acceptable_photos

  # Validate photo file types and sizes
  def acceptable_photos
    return unless photos.attached?

    photos.each do |photo|
      # Max 10MB per photo
      if photo.blob.byte_size > 10.megabytes
        errors.add(:photos, "contains a file that is too large (max 10MB per photo)")
        break
      end

      # Only images
      acceptable_types = [ "image/jpeg", "image/png", "image/gif", "image/webp" ]
      unless acceptable_types.include?(photo.blob.content_type)
        errors.add(:photos, "must be JPEG, PNG, GIF, or WebP")
        break
      end
    end

    # Max 10 photos per suggestion
    if photos.size > 10
      errors.add(:photos, "cannot upload more than 10 photos at once")
    end
  end

  # Sanitize description
  before_save :sanitize_description

  scope :pending_review, -> { pending.order(created_at: :asc) }
  scope :for_location, ->(location) { where(location: location) }

  def approve!(admin, notes: nil)
    return false unless pending?

    transaction do
      if photos.attached?
        photos.each do |photo|
          location.photos.attach(photo.blob)
        end
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

    downloaded_file = URI.open(photo_url, read_timeout: 30) # rubocop:disable Security/Open

    # Generate safe filename based on content type, not URL
    # This prevents PHP injection attacks via malicious filenames like "shell.php"
    filename = generate_safe_filename(downloaded_file.content_type)

    location.photos.attach(
      io: downloaded_file,
      filename: filename,
      content_type: sanitize_content_type(downloaded_file.content_type)
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

  def preview_urls
    if photos.attached?
      photos.map { |photo| Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true) }
    elsif photo_url.present?
      [ photo_url ]
    else
      []
    end
  end

  # For backwards compatibility
  def preview_url
    preview_urls.first
  end

  def photos_count
    if photos.attached?
      photos.size
    elsif photo_url.present?
      1
    else
      0
    end
  end

  private

  # Generate a safe filename that cannot be used for code injection
  # Uses content type to determine extension, not the URL path
  def generate_safe_filename(content_type)
    extension = case content_type&.downcase
    when /png/ then ".png"
    when /gif/ then ".gif"
    when /webp/ then ".webp"
    else ".jpg"
    end

    "photo_#{id}_#{SecureRandom.hex(4)}#{extension}"
  end

  # Sanitize content type to only allow safe image types
  def sanitize_content_type(content_type)
    allowed_types = %w[image/jpeg image/png image/gif image/webp]
    allowed_types.include?(content_type&.downcase) ? content_type : "image/jpeg"
  end

  def photos_or_url_present
    unless photos.attached? || photo_url.present?
      errors.add(:base, "Must provide either photo files or a photo URL")
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

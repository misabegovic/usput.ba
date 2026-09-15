# frozen_string_literal: true

class Moment < ApplicationRecord
  include Identifiable
  include Browsable

  belongs_to :user
  belongs_to :plan
  belongs_to :location

  has_many :likes, as: :likeable, dependent: :destroy

  enum :visibility, { private_moment: 0, public_moment: 1 }, prefix: true
  enum :moderation_status, { pending: 0, approved: 1, rejected: 2 }

  has_one_attached :photo do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 200, 200 ]
    attachable.variant :square, resize_to_fill: [ 600, 600 ]
  end

  # Validations
  ACCEPTABLE_PHOTO_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  validates :note, length: { maximum: 1000 }
  validate :photo_present
  validate :acceptable_photo

  # A moment is never visible on publish alone — going public re-enters
  # moderation, so a curator must approve it before anyone else can see it.
  before_save :require_moderation_when_published

  # One page of a moments grid. Each row drags a photo and its blob, so a
  # surface asks for a page rather than the lot.
  PAGE_SIZE = 12

  # Scopes
  scope :chronological, -> { order(created_at: :asc) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :publicly_visible, -> { visibility_public_moment.approved }
  # nil for a signed-out reader, where there is nothing of theirs to leave out.
  scope :not_by, ->(user) { where.not(user_id: user.id) if user }

  # Mirrors Location#display_photos: .variant on a non-image blob raises.
  def displayable?
    photo.attached? && photo.blob&.variable?
  end

  # The badge's colour, ordered the same way its words are. Spelled out in full
  # because Tailwind only generates class names it can read in the source — a
  # built-up string would leave the badge with no background and no error.
  def status_classes
    return "bg-gray-900/80 text-yellow-200" if visibility_private_moment?

    approved? ? "bg-emerald-900/80 text-emerald-100" : "bg-amber-900/80 text-amber-100"
  end

  # Private wins first: publishing is what sends a moment to moderation, so a
  # private moment can also be pending — reading approval first would label it
  # pending when what the traveller needs to know is that it is private.
  def status_key
    return "plans.start.story_private" if visibility_private_moment?

    approved? ? "plans.start.story_public" : "plans.start.story_pending"
  end

  # No audience, no reaction: private is seen by one, pending by none.
  def likeable?
    visibility_public_moment? && approved?
  end

  # A link is only worth offering where a stranger opening it finds the moment.
  def shareable?
    likeable?
  end

  def liked_by?(user)
    return false if user.nil?

    likes.exists?(user_id: user.id)
  end

  private

  def require_moderation_when_published
    self.moderation_status = :pending if visibility_public_moment? && visibility_changed?
  end

  def photo_present
    errors.add(:photo, :blank) unless photo.attached?
  end

  def acceptable_photo
    return unless photo.attached?

    if photo.blob.byte_size > 10.megabytes
      errors.add(:photo, "is too large (max 10MB)")
      return
    end

    unless ACCEPTABLE_PHOTO_TYPES.include?(photo.blob.content_type)
      errors.add(:photo, "must be JPEG, PNG, GIF, or WebP")
    end
  end
end

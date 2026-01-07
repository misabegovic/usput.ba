class CuratorApplication < ApplicationRecord
  include Identifiable

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2
  }, default: :pending

  validates :motivation, presence: true, length: { minimum: 50, maximum: 2000 }
  validates :experience, length: { maximum: 2000 }, allow_blank: true
  validate :user_not_already_curator, on: :create
  validate :no_pending_application, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def approve!(admin)
    transaction do
      update!(
        status: :approved,
        reviewed_by: admin,
        reviewed_at: Time.current
      )
      user.update!(user_type: :curator)
    end
  end

  def reject!(admin, notes = nil)
    update!(
      status: :rejected,
      reviewed_by: admin,
      reviewed_at: Time.current,
      admin_notes: notes
    )
  end

  private

  def user_not_already_curator
    if user&.can_curate?
      errors.add(:base, I18n.t("curator_applications.errors.already_curator"))
    end
  end

  def no_pending_application
    if user && CuratorApplication.where(user: user, status: :pending).exists?
      errors.add(:base, I18n.t("curator_applications.errors.pending_exists"))
    end
  end
end

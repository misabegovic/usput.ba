class PlanExperience < ApplicationRecord
  # Asocijacije
  belongs_to :plan
  belongs_to :experience

  # Validacije
  validates :day_number, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  # Allow same experience on different days (unique per plan+experience+day via DB index)
  validates :experience_id, uniqueness: { scope: [:plan_id, :day_number], message: "already exists on this day" }

  # Scopes
  scope :ordered, -> { order(day_number: :asc, position: :asc) }
  scope :for_day, ->(day_num) { where(day_number: day_num) }

  # Callbacks
  before_validation :set_default_position, on: :create

  # Pomjeri na novu poziciju unutar istog dana
  def move_to_position(new_position)
    return if position == new_position

    transaction do
      if new_position > position
        plan.plan_experiences
          .where(day_number: day_number, position: (position + 1)..new_position)
          .update_all("position = position - 1")
      else
        plan.plan_experiences
          .where(day_number: day_number, position: new_position..(position - 1))
          .update_all("position = position + 1")
      end
      update!(position: new_position)
    end
  end

  # Premjesti na drugi dan
  def move_to_day(new_day_number, new_position: nil)
    return if day_number == new_day_number && (new_position.nil? || position == new_position)

    transaction do
      # Smanji pozicije u trenutnom danu
      plan.plan_experiences
        .where(day_number: day_number)
        .where("position > ?", position)
        .update_all("position = position - 1")

      # Postavi novu poziciju
      pos = new_position || next_position_for_day(new_day_number)

      update!(day_number: new_day_number, position: pos)
    end
  end

  # Datum za ovaj experience u planu
  def scheduled_date
    plan.date_for_day(day_number)
  end

  private

  def set_default_position
    return if position.present?

    self.position = next_position_for_day(day_number)
  end

  def next_position_for_day(day_num)
    (plan&.plan_experiences&.where(day_number: day_num)&.maximum(:position) || 0) + 1
  end

end

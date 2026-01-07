class ExperienceLocation < ApplicationRecord
  # Asocijacije
  belongs_to :experience
  belongs_to :location

  # Validations
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :location_id, uniqueness: { scope: :experience_id, message: "already exists in this experience" }

  # Scopes
  scope :ordered, -> { order(position: :asc) }

  # Callbacks - automatski postavi poziciju ako nije zadana
  before_validation :set_default_position, on: :create

  # Pomjeri na novu poziciju
  def move_to(new_position)
    return if position == new_position

    transaction do
      if new_position > position
        # Pomjeramo dolje - smanjujemo pozicije između
        experience.experience_locations
          .where(position: (position + 1)..new_position)
          .update_all("position = position - 1")
      else
        # Pomjeramo gore - povećavamo pozicije između
        experience.experience_locations
          .where(position: new_position..(position - 1))
          .update_all("position = position + 1")
      end
      update!(position: new_position)
    end
  end

  private

  def set_default_position
    return if position.present?

    max_position = experience&.experience_locations&.maximum(:position) || 0
    self.position = max_position + 1
  end
end

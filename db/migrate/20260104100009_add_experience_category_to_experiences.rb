class AddExperienceCategoryToExperiences < ActiveRecord::Migration[8.1]
  def change
    add_reference :experiences, :experience_category, null: true, foreign_key: true
  end
end

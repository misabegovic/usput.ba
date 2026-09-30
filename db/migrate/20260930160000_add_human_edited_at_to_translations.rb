class AddHumanEditedAtToTranslations < ActiveRecord::Migration[8.1]
  def change
    add_column :translations, :human_edited_at, :datetime
  end
end

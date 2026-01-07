class CreateAudioTours < ActiveRecord::Migration[8.1]
  def change
    create_table :audio_tours do |t|
      t.references :location, null: false, foreign_key: true
      t.string :locale, null: false, default: "bs"
      t.text :script
      t.integer :word_count
      t.string :duration
      t.string :tts_provider
      t.string :voice_id
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Ensure one audio tour per location per language
    add_index :audio_tours, [:location_id, :locale], unique: true
    add_index :audio_tours, :locale
  end
end

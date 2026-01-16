class CreateKnowledgeSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_summaries do |t|
      t.string :dimension, null: false      # "region", "category", "city"
      t.string :dimension_value, null: false # "mostar", "restaurant", "Sarajevo"
      t.text :summary                        # AI-generated summary text
      t.jsonb :stats, default: {}            # Statistics about the dimension
      t.jsonb :issues, default: []           # Identified issues/gaps
      t.jsonb :patterns, default: []         # Detected patterns
      t.integer :source_count, default: 0    # Number of records summarized
      t.datetime :generated_at               # When summary was generated

      t.timestamps

      # Unique constraint on dimension + value
      t.index [:dimension, :dimension_value], unique: true, name: "idx_summaries_dimension_value"
      t.index :dimension
      t.index :generated_at
    end
  end
end

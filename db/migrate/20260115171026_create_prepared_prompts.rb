class CreatePreparedPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :prepared_prompts do |t|
      t.string :prompt_type, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.string :status, default: "pending"
      t.string :severity
      t.jsonb :metadata, default: {}
      t.uuid :conversation_id
      t.text :analysis
      t.text :solution
      t.string :target_file
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :prepared_prompts, :status
    add_index :prepared_prompts, :prompt_type
    add_index :prepared_prompts, :severity
  end
end

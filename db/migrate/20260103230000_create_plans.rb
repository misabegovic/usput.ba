class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :title, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.references :city, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end

    add_index :plans, :start_date
    add_index :plans, :end_date
    add_index :plans, [:start_date, :end_date]
  end
end

class AddUniqueIndexOnExploreBosniaPlans < ActiveRecord::Migration[8.1]
  def change
    # explore_bosnia_for is find-or-create, and two GETs for the same traveller
    # can both miss and both create. Only the database can refuse the second.
    add_index :plans, :user_id, unique: true,
              where: "(preferences ->> 'explore_bosnia') = 'true'",
              name: "index_plans_on_user_id_explore_bosnia"
  end
end

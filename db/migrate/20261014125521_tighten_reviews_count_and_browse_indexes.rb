# reviews_count defaulted to 0 but allowed NULL, so every reader had to treat
# it as maybe-nil (Roundhouse's "Integer?" findings, 2026-10-14). And browses
# carried the same (browsable_type, browsable_id) index twice, once unique.
class TightenReviewsCountAndBrowseIndexes < ActiveRecord::Migration[8.1]
  TABLES = %i[locations experiences plans browses].freeze

  def up
    TABLES.each do |table|
      execute "UPDATE #{table} SET reviews_count = 0 WHERE reviews_count IS NULL"
      change_column_null table, :reviews_count, false
    end
    remove_index :browses, name: "index_browses_on_browsable"
  end

  def down
    add_index :browses, %i[browsable_type browsable_id], name: "index_browses_on_browsable"
    TABLES.each { |table| change_column_null table, :reviews_count, true }
  end
end

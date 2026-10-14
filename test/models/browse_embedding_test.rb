# frozen_string_literal: true

require "test_helper"

# The embedding column under semantic search: one 1536-dimension vector per
# search row, compared by cosine distance.
class BrowseEmbeddingTest < ActiveSupport::TestCase
  DIMENSIONS = 1536

  test "a row stores its embedding with the model and digest beside it" do
    row = browse_for("Vrelo Bosne")

    row.update!(embedding: axis(0), embedding_model: "text-embedding-3-small", embedding_digest: "abc")

    row.reload
    assert_equal DIMENSIONS, row.embedding.size
    assert_equal "text-embedding-3-small", row.embedding_model
    assert_equal "abc", row.embedding_digest
  end

  test "a row without an embedding is still a search row" do
    row = browse_for("Kravice")

    assert_nil row.embedding
    assert Browse.exists?(row.id)
  end

  test "nearest neighbours come back closest first by cosine distance" do
    near = browse_for("Near").tap { |row| row.update!(embedding: mix(0, 1, 0.1)) }
    far = browse_for("Far").tap { |row| row.update!(embedding: mix(0, 1, 0.9)) }
    browse_for("Unembedded")

    neighbours = Browse.nearest_neighbors(:embedding, axis(0), distance: "cosine").first(2)

    assert_equal [ near, far ], neighbours
  end

  test "a vector of the wrong size is refused" do
    row = browse_for("Wrong size")

    error = assert_raises(ActiveRecord::RecordInvalid) { row.update!(embedding: [ 1.0, 0.0, 0.0 ]) }
    assert_match "1536", error.message
  end

  private

  def browse_for(name)
    location = Location.create!(name: name, city: "Sarajevo", lat: 43.8 + rand * 0.1, lng: 18.4 + rand * 0.1)
    Browse.sync_record(location)
    Browse.find_by!(browsable: location)
  end

  def axis(index)
    Array.new(DIMENSIONS, 0.0).tap { |vector| vector[index] = 1.0 }
  end

  # A unit-ish vector between two axes; weight 0 is the first axis, 1 the second.
  def mix(first, second, weight)
    Array.new(DIMENSIONS, 0.0).tap do |vector|
      vector[first] = 1.0 - weight
      vector[second] = weight
    end
  end
end

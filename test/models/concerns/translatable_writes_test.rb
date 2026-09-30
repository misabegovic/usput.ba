# frozen_string_literal: true

require "test_helper"

class TranslatableWritesTest < ActiveSupport::TestCase
  setup do
    @place = Location.create!(name: "Stari most", city: "Mostar")
  end

  teardown do
    Current.reset
  end

  test "a per-language setter is saved with the record, not before" do
    @place.name_de = "Alte Brücke"

    assert_empty Translation.where(translatable: @place, locale: "de")
    @place.save!
    assert_equal "Alte Brücke", @place.reload.name_de
  end

  test "a per-language getter reads that language only" do
    @place.update!(name_en: "Old Bridge")

    assert_equal "Old Bridge", @place.reload.name_en
    assert_nil @place.name_de, "German must not fall back to English on a form"
  end

  test "a blank value removes the translation" do
    @place.update!(name_de: "Alte Brücke")

    @place.reload.update!(name_de: "")

    assert_nil @place.reload.name_de
  end

  test "a change made in the admin is marked as a person's" do
    Current.editor = User.new
    @place.update!(description_de: "Von Hand")

    assert Translation.find_by(translatable: @place, locale: "de", field_name: "description").human_edited_at.present?
  end

  test "a change made outside the admin is not marked" do
    @place.update!(description_de: "Von der KI")

    assert_nil Translation.find_by(translatable: @place, locale: "de", field_name: "description").human_edited_at
  end

  test "saving the same value again keeps the translation as it was" do
    @place.update!(description_de: "Von der KI")
    Current.editor = User.new

    @place.reload.update!(description_de: "Von der KI")

    assert_nil Translation.find_by(translatable: @place, locale: "de", field_name: "description").human_edited_at
  end

  test "a record that fails validation leaves its translations untouched" do
    @place.update!(name_de: "Alte Brücke")
    point = StaticArtifacts::POINTS[:inside]

    assert_not @place.reload.update(name_de: "Neu", lat: point[:lat], lng: point[:lon])

    assert_equal "Alte Brücke", @place.reload.name_de
  end
end

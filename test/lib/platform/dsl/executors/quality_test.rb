# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::QualityTest < ActiveSupport::TestCase
  setup do
    # Create test locations with varying quality
    @complete_location = Location.create!(
      name: "Complete Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
    @complete_location.set_translation(:description, "This is a complete Bosnian description with more than 100 characters to meet the quality standards.", :bs)
    @complete_location.set_translation(:description, "This is a complete English description with more than 100 characters to meet the quality standards.", :en)

    @incomplete_location = Location.create!(
      name: "Incomplete Location",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )
    # No translations

    # Create test experiences
    @complete_experience = Experience.create!(
      title: "Complete Experience",
      estimated_duration: 120
    )
    @complete_experience.set_translation(:title, "Kompletno iskustvo", :bs)
    @complete_experience.set_translation(:description, "This is a complete Bosnian description for the experience with more than 150 characters to meet quality standards for experiences.", :bs)
    @complete_experience.set_translation(:description, "This is a complete English description for the experience with more than 150 characters to meet quality standards for experiences.", :en)
    @complete_experience.experience_locations.create!(location: @complete_location, position: 1)
    @complete_experience.experience_locations.create!(location: @incomplete_location, position: 2)

    @incomplete_experience = Experience.create!(
      title: "Incomplete Experience",
      estimated_duration: 60
    )
    # No translations, no locations
  end

  test "execute_quality_query with stats returns quality statistics" do
    ast = { type: :quality_query, filters: {}, operations: [{ name: :stats }] }

    result = Platform::DSL::Executors::Quality.execute_quality_query(ast)

    assert result[:locations].present?
    assert result[:experiences].present?
    assert result[:overall_quality_score].present?
    assert result[:formatted].present?
    assert result[:locations][:total] >= 2
    assert result[:experiences][:total] >= 2
  end

  test "execute_quality_query defaults to stats when no operation" do
    ast = { type: :quality_query, filters: {}, operations: nil }

    result = Platform::DSL::Executors::Quality.execute_quality_query(ast)

    assert result[:locations].present?
    assert result[:overall_quality_score].present?
  end

  test "execute_quality_query with audit returns full audit" do
    ast = { type: :quality_query, filters: {}, operations: [{ name: :audit }] }

    result = Platform::DSL::Executors::Quality.execute_quality_query(ast)

    assert result[:summary].present?
    assert result[:summary][:total_locations] >= 2
    assert result[:summary][:total_experiences] >= 2
    assert result[:issues_breakdown].present?
  end

  test "execute_quality_query with locations lists incomplete locations" do
    ast = { type: :quality_query, filters: { limit: 20 }, operations: [{ name: :locations }] }

    result = Platform::DSL::Executors::Quality.execute_quality_query(ast)

    assert_equal "incomplete_locations", result[:type]
    assert result[:count] >= 0
    assert result[:items].is_a?(Array)
  end

  test "execute_quality_query with experiences lists incomplete experiences" do
    ast = { type: :quality_query, filters: { limit: 20 }, operations: [{ name: :experiences }] }

    result = Platform::DSL::Executors::Quality.execute_quality_query(ast)

    assert_equal "incomplete_experiences", result[:type]
    assert result[:count] >= 0
    assert result[:items].is_a?(Array)
  end

  test "execute_quality_query raises error for unknown operation" do
    ast = { type: :quality_query, filters: {}, operations: [{ name: :unknown_op }] }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Quality.execute_quality_query(ast)
    end

    assert_match(/unknown_op/, error.message)
  end

  test "quality stats formatted output includes report sections" do
    ast = { type: :quality_query, filters: {}, operations: [{ name: :stats }] }

    result = Platform::DSL::Executors::Quality.execute_quality_query(ast)

    formatted = result[:formatted]
    assert_match(/QUALITY REPORT/, formatted)
    assert_match(/LOKACIJE/, formatted)
    assert_match(/ISKUSTVA/, formatted)
    assert_match(/QUALITY SCORE/, formatted)
  end
end

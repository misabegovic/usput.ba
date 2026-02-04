# frozen_string_literal: true

require "test_helper"

class PromptHelperTest < ActiveSupport::TestCase
  include PromptHelper

  test "loads erb prompt with simple variables" do
    prompt = load_prompt("experience_type_classifier/system.md.erb",
      available_types: "nature, culture, adventure")

    assert_includes prompt, "experience type classifier"
    assert_includes prompt, "Bosnia and Herzegovina"
    assert_includes prompt, "nature, culture, adventure"
  end

  test "loads erb prompt with location variables" do
    prompt = load_prompt("experience_type_classifier/classify.md.erb",
      name: "Stari Most",
      city: "Mostar",
      category: "Bridge",
      description_bs: "Historijski osmanski most",
      description_en: "Historic Ottoman bridge",
      tags: [ "historic", "unesco" ],
      hints: nil)

    assert_includes prompt, "Stari Most"
    assert_includes prompt, "Mostar"
    assert_includes prompt, "Bridge"
    assert_includes prompt, "historic, unesco"
  end

  test "handles nil optional variables in erb prompt" do
    prompt = load_prompt("experience_type_classifier/classify.md.erb",
      name: "Test Location",
      city: "Sarajevo",
      category: "Museum",
      description_bs: nil,
      description_en: nil,
      tags: nil,
      hints: nil)

    assert_includes prompt, "Test Location"
    assert_includes prompt, "Sarajevo"
    refute_includes prompt, "Description"
    refute_includes prompt, "Tags"
  end

  test "raises error for missing prompt" do
    assert_raises(ArgumentError) do
      load_prompt("nonexistent/prompt.md")
    end
  end

  test "lists available prompts" do
    prompts = available_prompts

    assert_includes prompts, "experience_type_classifier/system.md.erb"
    assert_includes prompts, "experience_type_classifier/classify.md.erb"
    assert_includes prompts, "location_enricher/metadata.md.erb"
    assert_includes prompts, "audio_tour_generator/script.md.erb"
    assert prompts.length >= 6
  end
end

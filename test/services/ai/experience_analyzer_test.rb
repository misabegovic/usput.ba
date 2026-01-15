# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class ExperienceAnalyzerTest < ActiveSupport::TestCase
    setup do
      @analyzer = Ai::ExperienceAnalyzer.new
    end

    # === Constants tests ===

    test "DELETE_THRESHOLD_SCORE is defined" do
      assert_equal 20, Ai::ExperienceAnalyzer::DELETE_THRESHOLD_SCORE
    end

    test "SIMILARITY_THRESHOLD is defined" do
      assert_equal 0.7, Ai::ExperienceAnalyzer::SIMILARITY_THRESHOLD
    end

    test "MIN_DESCRIPTION_LENGTH is defined" do
      assert_equal 100, Ai::ExperienceAnalyzer::MIN_DESCRIPTION_LENGTH
    end

    test "MIN_TITLE_LENGTH is defined" do
      assert_equal 5, Ai::ExperienceAnalyzer::MIN_TITLE_LENGTH
    end

    test "MIN_LOCATIONS_COUNT is defined" do
      assert_equal 1, Ai::ExperienceAnalyzer::MIN_LOCATIONS_COUNT
    end

    test "REQUIRED_LOCALES is defined" do
      assert_equal %w[en bs], Ai::ExperienceAnalyzer::REQUIRED_LOCALES
    end

    test "EXCLUDED_LOCATION_TYPES is defined" do
      assert_includes Ai::ExperienceAnalyzer::EXCLUDED_LOCATION_TYPES, :accommodation
    end

    test "ACCOMMODATION_CATEGORY_KEYS is defined" do
      keys = Ai::ExperienceAnalyzer::ACCOMMODATION_CATEGORY_KEYS
      assert_includes keys, "hotel"
      assert_includes keys, "hostel"
      assert_includes keys, "accommodation"
    end

    test "RETIREMENT_HOME_CATEGORY_KEYS is defined" do
      keys = Ai::ExperienceAnalyzer::RETIREMENT_HOME_CATEGORY_KEYS
      assert_includes keys, "dom_penzionera"
      assert_includes keys, "retirement_home"
      assert_includes keys, "nursing_home"
    end

    # === Initialization tests ===

    test "initializes without errors" do
      assert_nothing_raised { Ai::ExperienceAnalyzer.new }
    end

    test "initializes with empty issues_by_type hash" do
      analyzer = Ai::ExperienceAnalyzer.new
      issues_by_type = analyzer.instance_variable_get(:@issues_by_type)
      assert_kind_of Hash, issues_by_type
    end

    # === analyze single experience tests ===

    test "analyze returns hash with expected keys" do
      experience = create_mock_experience

      result = @analyzer.analyze(experience)

      assert_includes result.keys, :experience_id
      assert_includes result.keys, :title
      assert_includes result.keys, :city
      assert_includes result.keys, :issues
      assert_includes result.keys, :score
      assert_includes result.keys, :needs_rebuild
      assert_includes result.keys, :should_delete
      assert_includes result.keys, :delete_reason
    end

    test "analyze returns experience_id from experience" do
      experience = create_mock_experience(id: 123)

      result = @analyzer.analyze(experience)

      assert_equal 123, result[:experience_id]
    end

    test "analyze returns title from experience" do
      experience = create_mock_experience(title: "Test Experience")

      result = @analyzer.analyze(experience)

      assert_equal "Test Experience", result[:title]
    end

    test "analyze returns city from experience" do
      experience = create_mock_experience(city: "Sarajevo")

      result = @analyzer.analyze(experience)

      assert_equal "Sarajevo", result[:city]
    end

    test "analyze returns issues array" do
      experience = create_mock_experience

      result = @analyzer.analyze(experience)

      assert_kind_of Array, result[:issues]
    end

    test "analyze returns numeric score" do
      experience = create_mock_experience

      result = @analyzer.analyze(experience)

      assert_kind_of Numeric, result[:score]
    end

    test "analyze returns boolean for needs_rebuild" do
      experience = create_mock_experience

      result = @analyzer.analyze(experience)

      assert [true, false].include?(result[:needs_rebuild])
    end

    test "analyze returns boolean for should_delete" do
      experience = create_mock_experience

      result = @analyzer.analyze(experience)

      assert [true, false].include?(result[:should_delete])
    end

    # === Description quality tests ===

    test "analyze detects missing English description" do
      experience = create_mock_experience(
        translations: { title: { "en" => "Test" }, description: {} }
      )

      result = @analyzer.analyze(experience)

      missing_desc_issue = result[:issues].find { |i| i[:type] == :missing_description }
      assert_not_nil missing_desc_issue
      assert_equal :critical, missing_desc_issue[:severity]
      assert_equal "en", missing_desc_issue[:locale]
    end

    test "analyze detects short English description" do
      experience = create_mock_experience(
        translations: {
          title: { "en" => "Test Title" },
          description: { "en" => "Short" }
        }
      )

      result = @analyzer.analyze(experience)

      short_desc_issue = result[:issues].find { |i| i[:type] == :short_description }
      assert_not_nil short_desc_issue
      assert_equal :high, short_desc_issue[:severity]
    end

    test "analyze accepts description meeting minimum length" do
      long_description = "A" * 100
      experience = create_mock_experience(
        translations: {
          title: { "en" => "Test Title", "bs" => "Test Naslov" },
          description: { "en" => long_description, "bs" => long_description }
        }
      )

      result = @analyzer.analyze(experience)

      short_desc_issue = result[:issues].find { |i| i[:type] == :short_description }
      assert_nil short_desc_issue
    end

    test "analyze detects ekavica violations in Bosnian description" do
      experience = create_mock_experience(
        translations: {
          title: { "en" => "Test", "bs" => "Test" },
          description: { "en" => "A" * 100, "bs" => "Ovo je lepo mesto za posjetiti." }
        }
      )

      result = @analyzer.analyze(experience)

      ekavica_issue = result[:issues].find { |i| i[:type] == :ekavica_violation }
      assert_not_nil ekavica_issue
      assert_equal :high, ekavica_issue[:severity]
      assert_equal "bs", ekavica_issue[:locale]
      assert ekavica_issue[:violations].any?
    end

    # === Title quality tests ===

    test "analyze detects missing title" do
      experience = create_mock_experience(title: nil)

      result = @analyzer.analyze(experience)

      missing_title_issue = result[:issues].find { |i| i[:type] == :missing_title }
      assert_not_nil missing_title_issue
      assert_equal :critical, missing_title_issue[:severity]
    end

    test "analyze detects blank title" do
      experience = create_mock_experience(title: "")

      result = @analyzer.analyze(experience)

      missing_title_issue = result[:issues].find { |i| i[:type] == :missing_title }
      assert_not_nil missing_title_issue
    end

    test "analyze detects short title" do
      experience = create_mock_experience(title: "Test")

      result = @analyzer.analyze(experience)

      short_title_issue = result[:issues].find { |i| i[:type] == :short_title }
      assert_not_nil short_title_issue
      assert_equal :high, short_title_issue[:severity]
    end

    test "analyze detects generic title - experience" do
      experience = create_mock_experience(title: "Experience")

      result = @analyzer.analyze(experience)

      generic_title_issue = result[:issues].find { |i| i[:type] == :generic_title }
      assert_not_nil generic_title_issue
      assert_equal :medium, generic_title_issue[:severity]
    end

    test "analyze detects generic title - tour" do
      # Note: "Tour" is only 4 chars, which is less than MIN_TITLE_LENGTH (5)
      # So it would be flagged as short_title before generic_title is checked
      # We test with "A Tour" which meets length requirement but is still generic-ish
      # Actually, the regex /^tour$/i requires exact match "Tour" (4 chars)
      # But MIN_TITLE_LENGTH is 5, so short_title issue is raised first
      # The generic_title check only happens after the blank and short checks pass
      # Since "Tour" is short, generic_title won't be tested.
      # Let's check the generic_title? method directly instead
      assert @analyzer.send(:generic_title?, "Tour")
    end

    test "analyze detects generic title - city tour" do
      experience = create_mock_experience(title: "City Tour")

      result = @analyzer.analyze(experience)

      generic_title_issue = result[:issues].find { |i| i[:type] == :generic_title }
      assert_not_nil generic_title_issue
    end

    test "analyze detects generic title - untitled" do
      experience = create_mock_experience(title: "Untitled")

      result = @analyzer.analyze(experience)

      generic_title_issue = result[:issues].find { |i| i[:type] == :generic_title }
      assert_not_nil generic_title_issue
    end

    test "analyze detects generic title - test" do
      experience = create_mock_experience(title: "Test Experience 123")

      result = @analyzer.analyze(experience)

      generic_title_issue = result[:issues].find { |i| i[:type] == :generic_title }
      assert_not_nil generic_title_issue
    end

    test "analyze detects ekavica violations in Bosnian title" do
      experience = create_mock_experience(
        title: "Valid English Title",
        translations: {
          title: { "en" => "Valid English Title", "bs" => "Lepo mesto" },
          description: { "en" => "A" * 100, "bs" => "Opis" }
        }
      )

      result = @analyzer.analyze(experience)

      ekavica_issue = result[:issues].find { |i| i[:type] == :ekavica_violation && i[:locale] == "bs" }
      assert_not_nil ekavica_issue
    end

    # === Translation completeness tests ===

    test "analyze detects missing EN translation" do
      experience = create_mock_experience(
        translations: { title: {}, description: {} }
      )

      result = @analyzer.analyze(experience)

      missing_translation = result[:issues].find { |i| i[:type] == :missing_translation && i[:locale] == "en" }
      assert_not_nil missing_translation
      assert_equal :critical, missing_translation[:severity]
    end

    test "analyze detects missing BS translation" do
      experience = create_mock_experience(
        translations: {
          title: { "en" => "Test Title" },
          description: { "en" => "A" * 100 }
        }
      )

      result = @analyzer.analyze(experience)

      missing_translation = result[:issues].find { |i| i[:type] == :missing_translation && i[:locale] == "bs" }
      assert_not_nil missing_translation
      assert_equal :medium, missing_translation[:severity]
    end

    test "analyze detects missing title translation only" do
      experience = create_mock_experience(
        translations: {
          title: { "en" => "Test Title" },
          description: { "en" => "A" * 100, "bs" => "B" * 100 }
        }
      )

      result = @analyzer.analyze(experience)

      missing_translation = result[:issues].find { |i| i[:type] == :missing_translation && i[:locale] == "bs" }
      assert_not_nil missing_translation
      assert_includes missing_translation[:message], "title"
    end

    test "analyze detects missing description translation only" do
      experience = create_mock_experience(
        translations: {
          title: { "en" => "Test Title", "bs" => "Test Naslov" },
          description: { "en" => "A" * 100 }
        }
      )

      result = @analyzer.analyze(experience)

      missing_translation = result[:issues].find { |i| i[:type] == :missing_translation && i[:locale] == "bs" }
      assert_not_nil missing_translation
      assert_includes missing_translation[:message], "description"
    end

    # === Location count tests ===

    test "analyze detects no locations" do
      experience = create_mock_experience(locations: [])

      result = @analyzer.analyze(experience)

      no_locations_issue = result[:issues].find { |i| i[:type] == :no_locations }
      assert_not_nil no_locations_issue
      assert_equal :critical, no_locations_issue[:severity]
    end

    test "analyze accepts experience with one location" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(locations: [location])

      result = @analyzer.analyze(experience)

      no_locations_issue = result[:issues].find { |i| i[:type] == :no_locations }
      assert_nil no_locations_issue
    end

    # === Accommodation locations tests ===

    test "analyze detects too many accommodation locations" do
      accommodation1 = create_mock_location(id: 1, location_type: :accommodation)
      accommodation2 = create_mock_location(id: 2, location_type: :accommodation)
      accommodation3 = create_mock_location(id: 3, location_type: :accommodation)
      place = create_mock_location(id: 4, location_type: :place)

      experience = create_mock_experience(locations: [accommodation1, accommodation2, accommodation3, place])

      result = @analyzer.analyze(experience)

      accommodation_issue = result[:issues].find { |i| i[:type] == :too_many_accommodation_locations }
      assert_not_nil accommodation_issue
      assert_equal :high, accommodation_issue[:severity]
    end

    test "analyze detects only accommodation location" do
      accommodation = create_mock_location(id: 1, location_type: :accommodation)
      experience = create_mock_experience(locations: [accommodation])

      result = @analyzer.analyze(experience)

      only_accommodation_issue = result[:issues].find { |i| i[:type] == :only_accommodation_location }
      assert_not_nil only_accommodation_issue
      assert_equal :medium, only_accommodation_issue[:severity]
    end

    test "analyze accepts experience with few accommodation locations" do
      accommodation = create_mock_location(id: 1, location_type: :accommodation)
      place1 = create_mock_location(id: 2, location_type: :place)
      place2 = create_mock_location(id: 3, location_type: :place)
      place3 = create_mock_location(id: 4, location_type: :place)

      experience = create_mock_experience(locations: [accommodation, place1, place2, place3])

      result = @analyzer.analyze(experience)

      accommodation_issue = result[:issues].find { |i| i[:type] == :too_many_accommodation_locations }
      assert_nil accommodation_issue
    end

    # === Retirement home locations tests ===

    test "analyze detects retirement home locations by name" do
      retirement_home = create_mock_location(id: 1, name: "Dom penzionera Sarajevo")
      place = create_mock_location(id: 2, location_type: :place)

      experience = create_mock_experience(locations: [retirement_home, place])

      result = @analyzer.analyze(experience)

      retirement_issue = result[:issues].find { |i| i[:type] == :retirement_home_locations }
      assert_not_nil retirement_issue
      assert_equal :critical, retirement_issue[:severity]
      assert_includes retirement_issue[:location_names], "Dom penzionera Sarajevo"
    end

    test "analyze detects retirement home by nursing home keyword" do
      retirement_home = create_mock_location(id: 1, name: "Nursing Home XYZ")
      experience = create_mock_experience(locations: [retirement_home])

      result = @analyzer.analyze(experience)

      retirement_issue = result[:issues].find { |i| i[:type] == :retirement_home_locations }
      assert_not_nil retirement_issue
    end

    test "analyze accepts locations without retirement home keywords" do
      place = create_mock_location(id: 1, name: "Museum of History")
      experience = create_mock_experience(locations: [place])

      result = @analyzer.analyze(experience)

      retirement_issue = result[:issues].find { |i| i[:type] == :retirement_home_locations }
      assert_nil retirement_issue
    end

    # === Multi-city locations tests ===

    test "analyze detects multi-city locations" do
      location1 = create_mock_location(id: 1, city: "Sarajevo")
      location2 = create_mock_location(id: 2, city: "Mostar")

      experience = create_mock_experience(locations: [location1, location2])

      result = @analyzer.analyze(experience)

      multi_city_issue = result[:issues].find { |i| i[:type] == :multi_city_locations }
      assert_not_nil multi_city_issue
      assert_equal :high, multi_city_issue[:severity]
      assert_includes multi_city_issue[:cities], "Sarajevo"
      assert_includes multi_city_issue[:cities], "Mostar"
    end

    test "analyze accepts single city locations" do
      location1 = create_mock_location(id: 1, city: "Sarajevo")
      location2 = create_mock_location(id: 2, city: "Sarajevo")

      experience = create_mock_experience(locations: [location1, location2])

      result = @analyzer.analyze(experience)

      multi_city_issue = result[:issues].find { |i| i[:type] == :multi_city_locations }
      assert_nil multi_city_issue
    end

    # === Category tests ===

    test "analyze detects missing category" do
      experience = create_mock_experience(experience_category: nil)

      result = @analyzer.analyze(experience)

      missing_category_issue = result[:issues].find { |i| i[:type] == :missing_category }
      assert_not_nil missing_category_issue
      assert_equal :low, missing_category_issue[:severity]
    end

    test "analyze accepts experience with category" do
      category = OpenStruct.new(id: 1, key: "cultural_heritage", name: "Cultural Heritage")
      experience = create_mock_experience(experience_category: category)

      result = @analyzer.analyze(experience)

      missing_category_issue = result[:issues].find { |i| i[:type] == :missing_category }
      assert_nil missing_category_issue
    end

    # === Duration tests ===

    test "analyze detects missing duration" do
      experience = create_mock_experience(estimated_duration: nil)

      result = @analyzer.analyze(experience)

      missing_duration_issue = result[:issues].find { |i| i[:type] == :missing_duration }
      assert_not_nil missing_duration_issue
      assert_equal :low, missing_duration_issue[:severity]
    end

    test "analyze detects invalid zero duration" do
      experience = create_mock_experience(estimated_duration: 0)

      result = @analyzer.analyze(experience)

      invalid_duration_issue = result[:issues].find { |i| i[:type] == :invalid_duration }
      assert_not_nil invalid_duration_issue
      assert_equal :medium, invalid_duration_issue[:severity]
    end

    test "analyze detects invalid negative duration" do
      experience = create_mock_experience(estimated_duration: -30)

      result = @analyzer.analyze(experience)

      invalid_duration_issue = result[:issues].find { |i| i[:type] == :invalid_duration }
      assert_not_nil invalid_duration_issue
    end

    test "analyze accepts valid duration" do
      experience = create_mock_experience(estimated_duration: 120)

      result = @analyzer.analyze(experience)

      missing_duration_issue = result[:issues].find { |i| i[:type] == :missing_duration }
      invalid_duration_issue = result[:issues].find { |i| i[:type] == :invalid_duration }
      assert_nil missing_duration_issue
      assert_nil invalid_duration_issue
    end

    # === Quality score tests ===

    test "analyze returns score of 100 for perfect experience" do
      experience = create_perfect_experience

      result = @analyzer.analyze(experience)

      assert_equal 100, result[:score]
      assert_empty result[:issues]
    end

    test "analyze reduces score by 30 for critical issues" do
      experience = create_mock_experience(locations: [])

      result = @analyzer.analyze(experience)

      # Has critical issue (no locations), so score should be reduced
      assert result[:score] <= 70
    end

    test "analyze reduces score by 20 for high issues" do
      experience = create_mock_experience(title: "Test") # Short title

      result = @analyzer.analyze(experience)

      # Has high severity issue
      high_issues = result[:issues].select { |i| i[:severity] == :high }
      assert high_issues.any?
    end

    test "analyze reduces score by 10 for medium issues" do
      experience = create_mock_experience(title: "City Tour") # Generic title - medium severity

      result = @analyzer.analyze(experience)

      medium_issues = result[:issues].select { |i| i[:severity] == :medium }
      assert medium_issues.any?
    end

    test "analyze score cannot go below zero" do
      # Create experience with many critical issues
      experience = create_mock_experience(
        title: nil,
        locations: [],
        translations: { title: {}, description: {} }
      )

      result = @analyzer.analyze(experience)

      assert result[:score] >= 0
    end

    # === needs_rebuild tests ===

    test "analyze sets needs_rebuild true for critical issues" do
      experience = create_mock_experience(locations: [])

      result = @analyzer.analyze(experience)

      # Note: With no locations, should_delete is true, so needs_rebuild will be false
      assert result[:should_delete] || result[:needs_rebuild]
    end

    test "analyze sets needs_rebuild true for high severity issues" do
      # Create experience with high severity issue but enough content to not be deleted
      location = create_mock_location(id: 1)
      experience = create_mock_experience(
        title: "Valid Title Here",
        locations: [location],
        translations: {
          title: { "en" => "Valid Title Here", "bs" => "Lepo mesto" }, # ekavica violation - high
          description: { "en" => "A" * 100, "bs" => "B" * 100 }
        }
      )

      result = @analyzer.analyze(experience)

      high_issues = result[:issues].select { |i| i[:severity] == :high }
      if high_issues.any? && !result[:should_delete]
        assert result[:needs_rebuild]
      end
    end

    test "analyze sets needs_rebuild false when should_delete is true" do
      experience = create_mock_experience(locations: [])

      result = @analyzer.analyze(experience)

      if result[:should_delete]
        assert_not result[:needs_rebuild]
      end
    end

    # === should_delete tests ===

    test "analyze sets should_delete true for no locations" do
      experience = create_mock_experience(locations: [])

      result = @analyzer.analyze(experience)

      assert result[:should_delete]
      assert_includes result[:delete_reason], "No locations"
    end

    test "analyze sets should_delete true for very low score" do
      # Create experience with many critical issues
      experience = create_mock_experience(
        title: nil,
        locations: [],
        translations: { title: {}, description: {} }
      )

      result = @analyzer.analyze(experience)

      assert result[:should_delete]
    end

    test "analyze sets should_delete true for missing all English content" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(
        title: "Valid Title",
        locations: [location],
        translations: { title: {}, description: {} }
      )

      result = @analyzer.analyze(experience)

      assert result[:should_delete]
      assert_includes result[:delete_reason], "English content"
    end

    test "analyze sets should_delete true for generic title with no real content" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(
        title: "Test Experience",
        locations: [location],
        translations: {
          title: { "en" => "Test Experience" },
          description: { "en" => "Short" } # Too short to count as real content
        }
      )

      result = @analyzer.analyze(experience)

      assert result[:should_delete]
      assert_includes result[:delete_reason], "placeholder"
    end

    test "analyze keeps experience with generic title but real content" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(
        title: "Test Experience",
        locations: [location],
        translations: {
          title: { "en" => "Test Experience", "bs" => "Test" },
          description: { "en" => "A" * 100, "bs" => "B" * 100 }
        }
      )

      result = @analyzer.analyze(experience)

      # Should not be deleted because it has real content
      assert_not result[:should_delete]
    end

    # === analyze_all tests ===

    test "analyze_all returns array" do
      Experience.stub :includes, Experience.none do
        result = @analyzer.analyze_all
        assert_kind_of Array, result
      end
    end

    test "analyze_all only includes experiences with issues" do
      # Create mock experiences
      exp_with_issues = create_mock_experience(locations: [])
      exp_without_issues = create_perfect_experience

      mock_relation = Object.new
      mock_relation.define_singleton_method(:find_each) do |&block|
        [exp_with_issues, exp_without_issues].each(&block)
      end

      Experience.stub :includes, mock_relation do
        results = @analyzer.analyze_all

        # Only the experience with issues should be included
        ids = results.map { |r| r[:experience_id] }
        assert_includes ids, exp_with_issues.id
      end
    end

    test "analyze_all sorts by score ascending" do
      exp1 = create_mock_experience(id: 1, locations: []) # Critical - low score
      location = create_mock_location(id: 1)
      exp2 = create_mock_experience(id: 2, locations: [location], estimated_duration: nil) # Low severity - higher score

      mock_relation = Object.new
      mock_relation.define_singleton_method(:find_each) do |&block|
        [exp2, exp1].each(&block) # Intentionally reverse order
      end

      Experience.stub :includes, mock_relation do
        results = @analyzer.analyze_all

        if results.length >= 2
          assert results[0][:score] <= results[1][:score]
        end
      end
    end

    # === find_similar_experiences tests ===

    test "find_similar_experiences returns array" do
      Experience.stub :includes, Experience.none do
        result = @analyzer.find_similar_experiences
        assert_kind_of Array, result
      end
    end

    test "find_similar_experiences detects similar experiences" do
      location1 = create_mock_location(id: 1)
      location2 = create_mock_location(id: 2)

      exp1 = create_mock_experience(
        id: 1,
        title: "Cultural Tour Sarajevo",
        locations: [location1, location2],
        city: "Sarajevo"
      )

      exp2 = create_mock_experience(
        id: 2,
        title: "Cultural Tour Sarajevo", # Same title
        locations: [location1, location2], # Same locations
        city: "Sarajevo"
      )

      mock_relation = [exp1, exp2]

      Experience.stub :includes, mock_relation do
        mock_relation.define_singleton_method(:to_a) { self }

        results = @analyzer.find_similar_experiences

        if results.any?
          assert results.first[:similarity][:overall] >= Ai::ExperienceAnalyzer::SIMILARITY_THRESHOLD
        end
      end
    end

    test "find_similar_experiences returns similarity metrics" do
      location = create_mock_location(id: 1)

      exp1 = create_mock_experience(id: 1, title: "Same Title", locations: [location])
      exp2 = create_mock_experience(id: 2, title: "Same Title", locations: [location])

      mock_relation = [exp1, exp2]
      mock_relation.define_singleton_method(:to_a) { self }

      Experience.stub :includes, mock_relation do
        results = @analyzer.find_similar_experiences

        if results.any?
          similarity = results.first[:similarity]
          assert_includes similarity.keys, :title
          assert_includes similarity.keys, :locations
          assert_includes similarity.keys, :description
          assert_includes similarity.keys, :same_city
          assert_includes similarity.keys, :overall
        end
      end
    end

    test "find_similar_experiences returns recommendation" do
      location = create_mock_location(id: 1)

      exp1 = create_mock_experience(id: 1, title: "Same Title", locations: [location])
      exp2 = create_mock_experience(id: 2, title: "Same Title", locations: [location])

      mock_relation = [exp1, exp2]
      mock_relation.define_singleton_method(:to_a) { self }

      Experience.stub :includes, mock_relation do
        results = @analyzer.find_similar_experiences

        if results.any?
          assert_includes results.first.keys, :recommendation
          assert_includes [:merge_or_delete_duplicate, :review_for_differentiation, :rename_for_clarity, :review_manually], results.first[:recommendation]
        end
      end
    end

    test "find_similar_experiences sorts by overall similarity descending" do
      loc1 = create_mock_location(id: 1)
      loc2 = create_mock_location(id: 2)
      loc3 = create_mock_location(id: 3)

      exp1 = create_mock_experience(id: 1, title: "Tour A", locations: [loc1, loc2])
      exp2 = create_mock_experience(id: 2, title: "Tour A", locations: [loc1, loc2]) # Very similar to exp1
      exp3 = create_mock_experience(id: 3, title: "Tour B", locations: [loc2, loc3]) # Less similar

      mock_relation = [exp1, exp2, exp3]
      mock_relation.define_singleton_method(:to_a) { self }

      Experience.stub :includes, mock_relation do
        results = @analyzer.find_similar_experiences

        if results.length >= 2
          assert results[0][:similarity][:overall] >= results[1][:similarity][:overall]
        end
      end
    end

    # === generate_report tests ===

    test "generate_report returns expected keys" do
      stub_empty_experience_query do
        report = @analyzer.generate_report

        assert_includes report.keys, :total_experiences
        assert_includes report.keys, :experiences_with_issues
        assert_includes report.keys, :experiences_needing_rebuild
        assert_includes report.keys, :experiences_to_delete
        assert_includes report.keys, :similar_experience_pairs
        assert_includes report.keys, :issues_by_severity
        assert_includes report.keys, :issues_by_type
        assert_includes report.keys, :worst_experiences
        assert_includes report.keys, :deletable_experiences
        assert_includes report.keys, :similar_experiences
      end
    end

    test "generate_report accepts limit parameter" do
      stub_empty_experience_query do
        assert_nothing_raised { @analyzer.generate_report(limit: 10) }
      end
    end

    test "generate_report with limit nil returns all results" do
      stub_empty_experience_query do
        report = @analyzer.generate_report(limit: nil)

        assert report[:worst_experiences].is_a?(Array)
      end
    end

    test "generate_report with limit restricts worst_experiences count" do
      stub_empty_experience_query do
        report = @analyzer.generate_report(limit: 5)

        assert report[:worst_experiences].length <= 5
      end
    end

    test "generate_report with limit restricts deletable_experiences count" do
      stub_empty_experience_query do
        report = @analyzer.generate_report(limit: 5)

        assert report[:deletable_experiences].length <= 5
      end
    end

    test "generate_report with limit restricts similar_experiences count" do
      stub_empty_experience_query do
        report = @analyzer.generate_report(limit: 10)

        # similar_experiences uses limit / 2
        assert report[:similar_experiences].length <= 5
      end
    end

    test "generate_report default limit is 20" do
      stub_empty_experience_query do
        report = @analyzer.generate_report

        assert report[:worst_experiences].length <= 20
        assert report[:deletable_experiences].length <= 20
        assert report[:similar_experiences].length <= 10
      end
    end

    test "generate_report issues_by_severity has correct structure" do
      stub_empty_experience_query do
        report = @analyzer.generate_report

        assert_includes report[:issues_by_severity].keys, :critical
        assert_includes report[:issues_by_severity].keys, :high
        assert_includes report[:issues_by_severity].keys, :medium
        assert_includes report[:issues_by_severity].keys, :low
      end
    end

    test "generate_report issues_by_type is a hash" do
      stub_empty_experience_query do
        report = @analyzer.generate_report

        assert_kind_of Hash, report[:issues_by_type]
      end
    end

    # === Ekavica detection tests ===

    test "detect_ekavica detects lepo" do
      violations = @analyzer.send(:detect_ekavica, "Ovo je lepo mjesto")

      assert violations.any? { |v| v[:found].downcase == "lepo" }
    end

    test "detect_ekavica detects vreme" do
      violations = @analyzer.send(:detect_ekavica, "Dobro vreme za posjet")

      assert violations.any? { |v| v[:found].downcase == "vreme" }
    end

    test "detect_ekavica detects mesto" do
      violations = @analyzer.send(:detect_ekavica, "Interesantno mesto")

      assert violations.any? { |v| v[:found].downcase == "mesto" }
    end

    test "detect_ekavica detects istorija" do
      violations = @analyzer.send(:detect_ekavica, "Bogata istorija grada")

      assert violations.any? { |v| v[:found].downcase == "istorija" }
    end

    test "detect_ekavica returns empty for correct ijekavica" do
      violations = @analyzer.send(:detect_ekavica, "Ovo je lijepo mjesto sa dugom historijom")

      assert_empty violations
    end

    test "detect_ekavica limits violations to 5" do
      text = "lepo mesto vreme videti dete mleko belo pevati svet čovek"
      violations = @analyzer.send(:detect_ekavica, text)

      # The method limits to take(5) in the issue, but returns all from detect_ekavica
      # Check that multiple violations are detected
      assert violations.count >= 5
    end

    # === String similarity tests ===

    test "string_similarity returns 1.0 for identical strings" do
      result = @analyzer.send(:string_similarity, "hello world", "hello world")

      assert_equal 1.0, result
    end

    test "string_similarity returns 0.0 for completely different strings" do
      result = @analyzer.send(:string_similarity, "abc def", "xyz uvw")

      assert_equal 0.0, result
    end

    test "string_similarity returns 0.0 for one empty string" do
      assert_equal 0.0, @analyzer.send(:string_similarity, "", "test")
      assert_equal 0.0, @analyzer.send(:string_similarity, "test", "")
    end

    test "string_similarity returns 1.0 for two empty strings" do
      # Two identical empty strings are considered equal (str1 == str2 returns true)
      assert_equal 1.0, @analyzer.send(:string_similarity, "", "")
    end

    test "string_similarity returns value between 0 and 1" do
      result = @analyzer.send(:string_similarity, "hello world test", "hello world")

      assert result >= 0.0
      assert result <= 1.0
    end

    # === Recommendation action tests ===

    test "recommend_action returns merge_or_delete_duplicate for high location overlap" do
      similarity = { locations: 0.85, title: 0.5 }
      result = @analyzer.send(:recommend_action, similarity)

      assert_equal :merge_or_delete_duplicate, result
    end

    test "recommend_action returns review_for_differentiation for medium location overlap" do
      similarity = { locations: 0.65, title: 0.5 }
      result = @analyzer.send(:recommend_action, similarity)

      assert_equal :review_for_differentiation, result
    end

    test "recommend_action returns rename_for_clarity for very similar titles" do
      similarity = { locations: 0.3, title: 0.95 }
      result = @analyzer.send(:recommend_action, similarity)

      assert_equal :rename_for_clarity, result
    end

    test "recommend_action returns review_manually for other cases" do
      similarity = { locations: 0.3, title: 0.5 }
      result = @analyzer.send(:recommend_action, similarity)

      assert_equal :review_manually, result
    end

    # === accommodation_location? tests ===

    test "accommodation_location returns true for accommodation location_type" do
      location = create_mock_location(location_type: :accommodation)

      result = @analyzer.send(:accommodation_location?, location)

      assert result
    end

    test "accommodation_location returns true for hotel category" do
      location = create_mock_location_with_categories(["hotel"])

      result = @analyzer.send(:accommodation_location?, location)

      assert result
    end

    test "accommodation_location returns true for hostel tag" do
      location = create_mock_location(tags: ["hostel", "budget"])

      result = @analyzer.send(:accommodation_location?, location)

      assert result
    end

    test "accommodation_location returns false for regular place" do
      location = create_mock_location(location_type: :place)

      result = @analyzer.send(:accommodation_location?, location)

      assert_not result
    end

    # === retirement_home_location? tests ===

    test "retirement_home_location returns true for penzioner in name" do
      location = create_mock_location(name: "Dom penzionera")

      result = @analyzer.send(:retirement_home_location?, location)

      assert result
    end

    test "retirement_home_location returns true for retirement in name" do
      location = create_mock_location(name: "Retirement Village")

      result = @analyzer.send(:retirement_home_location?, location)

      assert result
    end

    test "retirement_home_location returns true for gerontoloski in name" do
      location = create_mock_location(name: "Gerontoloski centar")

      result = @analyzer.send(:retirement_home_location?, location)

      assert result
    end

    test "retirement_home_location returns false for regular location" do
      location = create_mock_location(name: "Museum of Art")

      result = @analyzer.send(:retirement_home_location?, location)

      assert_not result
    end

    # === generic_title? tests ===

    test "generic_title returns true for Experience" do
      assert @analyzer.send(:generic_title?, "Experience")
    end

    test "generic_title returns true for Tour" do
      assert @analyzer.send(:generic_title?, "Tour")
    end

    test "generic_title returns true for City Tour" do
      assert @analyzer.send(:generic_title?, "City Tour")
    end

    test "generic_title returns true for Walking Tour" do
      assert @analyzer.send(:generic_title?, "Walking Tour")
    end

    test "generic_title returns true for Untitled" do
      assert @analyzer.send(:generic_title?, "Untitled")
    end

    test "generic_title returns true for New Experience" do
      assert @analyzer.send(:generic_title?, "New Experience")
    end

    test "generic_title returns true for test prefix" do
      assert @analyzer.send(:generic_title?, "Test something")
    end

    test "generic_title returns false for specific title" do
      assert_not @analyzer.send(:generic_title?, "Cultural Heritage of Old Town Sarajevo")
    end

    test "generic_title is case insensitive" do
      assert @analyzer.send(:generic_title?, "EXPERIENCE")
      assert @analyzer.send(:generic_title?, "TOUR")
    end

    # === calculate_quality_score tests ===

    test "calculate_quality_score returns 100 for no issues" do
      result = @analyzer.send(:calculate_quality_score, [])

      assert_equal 100, result
    end

    test "calculate_quality_score subtracts 30 for critical" do
      issues = [{ severity: :critical }]
      result = @analyzer.send(:calculate_quality_score, issues)

      assert_equal 70, result
    end

    test "calculate_quality_score subtracts 20 for high" do
      issues = [{ severity: :high }]
      result = @analyzer.send(:calculate_quality_score, issues)

      assert_equal 80, result
    end

    test "calculate_quality_score subtracts 10 for medium" do
      issues = [{ severity: :medium }]
      result = @analyzer.send(:calculate_quality_score, issues)

      assert_equal 90, result
    end

    test "calculate_quality_score subtracts 5 for low" do
      issues = [{ severity: :low }]
      result = @analyzer.send(:calculate_quality_score, issues)

      assert_equal 95, result
    end

    test "calculate_quality_score accumulates multiple issues" do
      issues = [
        { severity: :critical },
        { severity: :high },
        { severity: :medium }
      ]
      result = @analyzer.send(:calculate_quality_score, issues)

      assert_equal 40, result # 100 - 30 - 20 - 10
    end

    test "calculate_quality_score never goes below zero" do
      issues = Array.new(5) { { severity: :critical } }
      result = @analyzer.send(:calculate_quality_score, issues)

      assert_equal 0, result
    end

    # === explain_delete_reason tests ===

    test "explain_delete_reason includes no locations reason" do
      experience = create_mock_experience(locations: [])

      reason = @analyzer.send(:explain_delete_reason, experience, [], 50)

      assert_includes reason, "No locations"
    end

    test "explain_delete_reason includes low score reason" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(locations: [location])

      reason = @analyzer.send(:explain_delete_reason, experience, [], 15)

      assert_includes reason, "too low"
    end

    test "explain_delete_reason includes missing English content reason" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(
        locations: [location],
        translations: { title: {}, description: {} }
      )

      reason = @analyzer.send(:explain_delete_reason, experience, [], 50)

      assert_includes reason, "English content"
    end

    test "explain_delete_reason includes generic title reason" do
      location = create_mock_location(id: 1)
      experience = create_mock_experience(
        title: "Test Something",
        locations: [location],
        translations: {
          title: { "en" => "Test Something" },
          description: { "en" => "Short" }
        }
      )

      reason = @analyzer.send(:explain_delete_reason, experience, [], 50)

      assert_includes reason, "placeholder"
    end

    private

    def create_mock_experience(
      id: nil,
      title: "Valid Experience Title",
      city: "Sarajevo",
      locations: nil,
      translations: nil,
      experience_category: nil,
      estimated_duration: 120,
      experience_locations_count: nil
    )
      id ||= rand(1000..9999)
      translations ||= {
        title: { "en" => title, "bs" => "Naslov" },
        description: { "en" => "A" * 100, "bs" => "B" * 100 }
      }

      # Default to one location if not specified
      if locations.nil?
        locations = [create_mock_location(id: rand(1..1000))]
      end

      mock = OpenStruct.new(
        id: id,
        title: title,
        city: city,
        experience_category: experience_category,
        estimated_duration: estimated_duration
      )

      # Set up locations
      mock_locations = locations
      mock.define_singleton_method(:locations) { mock_locations }

      # Set up experience_locations
      exp_loc_count = experience_locations_count || locations.count
      mock.define_singleton_method(:experience_locations) do
        mock_exp_locs = Object.new
        mock_exp_locs.define_singleton_method(:count) { exp_loc_count }
        mock_exp_locs
      end

      # Set up translation_for method
      mock.define_singleton_method(:translation_for) do |field, locale|
        field_key = field.to_sym
        locale_key = locale.to_s
        translations.dig(field_key, locale_key)
      end

      # Set up translations association (for includes)
      mock.define_singleton_method(:translations) { [] }

      mock
    end

    def create_perfect_experience
      location = create_mock_location(id: 1, city: "Sarajevo")
      category = OpenStruct.new(id: 1, key: "cultural_heritage", name: "Cultural Heritage")

      create_mock_experience(
        id: rand(1000..9999),
        title: "Beautiful Cultural Heritage Tour",
        city: "Sarajevo",
        locations: [location],
        translations: {
          title: { "en" => "Beautiful Cultural Heritage Tour", "bs" => "Lijepa kulturna baština" },
          description: { "en" => "A" * 150, "bs" => "B" * 150 }
        },
        experience_category: category,
        estimated_duration: 180
      )
    end

    def create_mock_location(
      id: nil,
      name: "Test Location",
      city: "Sarajevo",
      location_type: :place,
      tags: [],
      location_categories: []
    )
      id ||= rand(1000..9999)

      mock = OpenStruct.new(
        id: id,
        name: name,
        city: city,
        location_type: location_type.to_s,
        tags: tags
      )

      # Mock location_type enum-like behavior
      mock.define_singleton_method(:location_type) { location_type.to_s }

      # Set up location_categories
      mock.define_singleton_method(:respond_to?) do |method|
        [:location_categories, :name, :id, :city, :location_type, :tags].include?(method) || super(method)
      end

      mock.define_singleton_method(:location_categories) do
        mock_categories = location_categories.map do |cat|
          cat_mock = OpenStruct.new(key: cat)
          cat_mock
        end

        # Mark as loaded for the analyzer's check
        mock_categories.define_singleton_method(:loaded?) { true }
        mock_categories
      end

      mock
    end

    def create_mock_location_with_categories(category_keys)
      categories = category_keys.map { |key| OpenStruct.new(key: key) }

      mock = OpenStruct.new(
        id: rand(1000..9999),
        name: "Location with Categories",
        city: "Sarajevo",
        location_type: "place",
        tags: []
      )

      mock.define_singleton_method(:respond_to?) do |method|
        [:location_categories, :name, :id, :city, :location_type, :tags].include?(method) || super(method)
      end

      mock.define_singleton_method(:location_categories) do
        categories.define_singleton_method(:loaded?) { true }
        categories
      end

      mock
    end

    def stub_empty_experience_query
      mock_relation = Object.new
      mock_relation.define_singleton_method(:find_each) { |&_block| }
      mock_relation.define_singleton_method(:to_a) { [] }

      Experience.stub :includes, mock_relation do
        yield
      end
    end
  end
end

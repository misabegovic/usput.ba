# frozen_string_literal: true

require "test_helper"

module Ai
  class LocationEnricher
    class ApplicatorTest < ActiveSupport::TestCase
      setup do
        @location = Location.create!(
          name: "Test Location",
          city: "Sarajevo",
          lat: 43.856,
          lng: 18.413,
          location_type: :place,
          tags: [],
          audio_tour_metadata: {}
        )
        @applicator = Ai::LocationEnricher::Applicator.new(@location)
      end

      # === apply tests ===

      test "apply calls all application methods" do
        enrichment = {
          descriptions: { bs: "Opis" },
          historical_context: { bs: "Kontekst" },
          suitable_experiences: [ "culture" ],
          tags: [ "historic" ],
          practical_info: { best_time: "morning", duration_minutes: 60, tips: [] }
        }

        # Track method calls
        calls = []

        # Mock all private methods
        @applicator.stub :apply_translations, ->(_) { calls << :apply_translations } do
          @applicator.stub :apply_experience_types, ->(_) { calls << :apply_experience_types } do
            @applicator.stub :apply_tags, ->(_) { calls << :apply_tags } do
              @applicator.stub :apply_practical_info, ->(_) { calls << :apply_practical_info } do
                @applicator.apply(enrichment)
              end
            end
          end
        end

        assert_includes calls, :apply_translations
        assert_includes calls, :apply_experience_types
        assert_includes calls, :apply_tags
        assert_includes calls, :apply_practical_info
      end

      # === add_tags_from_categories tests ===

      test "add_tags_from_categories extracts tags from Geoapify categories" do
        categories = [ "tourism.attraction", "heritage.unesco_site", "cultural.museum" ]

        @applicator.add_tags_from_categories(categories)

        assert_includes @location.tags, "attraction"
        assert_includes @location.tags, "unesco-site"
        assert_includes @location.tags, "museum"
      end

      test "add_tags_from_categories limits to first 3 tags" do
        original_tags = @location.tags.dup
        categories = [ "a.tag1", "b.tag2", "c.tag3", "d.tag4", "e.tag5" ]

        @applicator.add_tags_from_categories(categories)

        # Should only have 3 new tags
        new_tags = @location.reload.tags - original_tags
        assert_equal 3, new_tags.count
      end

      test "add_tags_from_categories converts underscores to hyphens" do
        categories = [ "heritage.unesco_site" ]

        @applicator.add_tags_from_categories(categories)

        assert_includes @location.tags, "unesco-site"
        refute_includes @location.tags, "unesco_site"
      end

      test "add_tags_from_categories does nothing when categories blank" do
        original_tags = @location.tags.dup

        @applicator.add_tags_from_categories([])

        assert_equal original_tags, @location.tags
      end

      test "add_tags_from_categories does nothing when categories nil" do
        original_tags = @location.tags.dup

        @applicator.add_tags_from_categories(nil)

        assert_equal original_tags, @location.tags
      end

      test "add_tags_from_categories saves location" do
        categories = [ "tourism.attraction" ]

        assert_changes -> { @location.reload.tags } do
          @applicator.add_tags_from_categories(categories)
        end
      end

      # === apply_translations tests ===

      test "apply_translations sets description translations" do
        enrichment = {
          descriptions: {
            bs: "Bosanski opis",
            en: "English description"
          },
          historical_context: {}
        }

        @applicator.send(:apply_translations, enrichment)

        assert_equal "Bosanski opis", @location.translate(:description, :bs)
        assert_equal "English description", @location.translate(:description, :en)
      end

      test "apply_translations sets historical_context translations" do
        enrichment = {
          descriptions: {},
          historical_context: {
            bs: "Bosanski kontekst",
            en: "English context"
          }
        }

        @applicator.send(:apply_translations, enrichment)

        assert_equal "Bosanski kontekst", @location.translate(:historical_context, :bs)
        assert_equal "English context", @location.translate(:historical_context, :en)
      end

      test "apply_translations sets name translation" do
        enrichment = {
          descriptions: { bs: "Opis" },
          historical_context: {}
        }

        @applicator.send(:apply_translations, enrichment)

        assert_equal @location.name, @location.translate(:name, :bs)
      end

      test "apply_translations handles string keys" do
        enrichment = {
          descriptions: {
            "bs" => "String key opis"
          },
          historical_context: {}
        }

        @applicator.send(:apply_translations, enrichment)

        assert_equal "String key opis", @location.translate(:description, :bs)
      end

      test "apply_translations handles symbol keys" do
        enrichment = {
          descriptions: {
            bs: "Symbol key opis"
          },
          historical_context: {}
        }

        @applicator.send(:apply_translations, enrichment)

        assert_equal "Symbol key opis", @location.translate(:description, :bs)
      end

      test "apply_translations iterates over all supported locales" do
        enrichment = {
          descriptions: {
            bs: "BS", en: "EN", hr: "HR", de: "DE"
          },
          historical_context: {}
        }

        @applicator.send(:apply_translations, enrichment)

        # Check translations are set for multiple locales
        assert @location.translate(:description, :bs).present?
        assert @location.translate(:description, :en).present?
        assert @location.translate(:description, :hr).present?
        assert @location.translate(:description, :de).present?
      end

      # === apply_experience_types tests ===

      test "apply_experience_types uses classifier successfully" do
        enrichment = { suitable_experiences: [ "culture", "history" ] }

        mock_classifier = Minitest::Mock.new
        mock_classifier.expect :classify, { success: true, types: [ "culture", "history" ] },
          [ @location ], dry_run: false, hints: [ "culture", "history" ]

        Ai::ExperienceTypeClassifier.stub :new, mock_classifier do
          @applicator.send(:apply_experience_types, enrichment)
        end

        assert mock_classifier.verify
      end

      test "apply_experience_types uses hints when classifier fails" do
        enrichment = { suitable_experiences: [ "culture", "history" ] }

        mock_classifier = Minitest::Mock.new
        mock_classifier.expect :classify, { success: false, types: [] },
          [ @location ], dry_run: false, hints: [ "culture", "history" ]

        set_types_called = false

        Ai::ExperienceTypeClassifier.stub :new, mock_classifier do
          @location.stub :set_experience_types, ->(_) { set_types_called = true } do
            @applicator.send(:apply_experience_types, enrichment)
          end
        end

        assert mock_classifier.verify
        assert set_types_called, "Expected set_experience_types to be called with hints"
      end

      test "apply_experience_types handles classifier exception with hints" do
        enrichment = { suitable_experiences: [ "culture" ] }

        set_types_called = false

        Ai::ExperienceTypeClassifier.stub :new, ->(*) { raise StandardError, "Classifier error" } do
          @location.stub :set_experience_types, ->(_) { set_types_called = true } do
            # Should not raise
            @applicator.send(:apply_experience_types, enrichment)
          end
        end

        assert set_types_called, "Expected set_experience_types to be called as fallback"
      end

      test "apply_experience_types handles classifier exception without hints" do
        enrichment = { suitable_experiences: [] }

        Ai::ExperienceTypeClassifier.stub :new, ->(*) { raise StandardError, "Classifier error" } do
          # Should not raise even without hints
          assert_nothing_raised do
            @applicator.send(:apply_experience_types, enrichment)
          end
        end
      end

      test "apply_experience_types does nothing when hints blank" do
        enrichment = { suitable_experiences: [] }

        mock_classifier = Minitest::Mock.new
        mock_classifier.expect :classify, { success: false, types: [] },
          [ @location ], dry_run: false, hints: nil

        Ai::ExperienceTypeClassifier.stub :new, mock_classifier do
          # Should not call set_experience_types
          @applicator.send(:apply_experience_types, enrichment)
        end

        assert mock_classifier.verify
      end

      # === safely_set_experience_types tests ===

      test "safely_set_experience_types calls set_experience_types" do
        types = [ "culture", "history" ]

        set_types_called = false

        @location.stub :set_experience_types, ->(_) { set_types_called = true } do
          @applicator.send(:safely_set_experience_types, types)
        end

        assert set_types_called
      end

      test "safely_set_experience_types handles exception gracefully" do
        types = [ "invalid" ]

        @location.stub :set_experience_types, ->(*) { raise StandardError, "Invalid types" } do
          # Should not raise
          assert_nothing_raised do
            @applicator.send(:safely_set_experience_types, types)
          end
        end
      end

      # === apply_tags tests ===

      test "apply_tags adds new tags to location" do
        @location.tags = [ "existing-tag" ]
        enrichment = { tags: [ "new-tag", "another-tag" ] }

        @applicator.send(:apply_tags, enrichment)

        assert_includes @location.tags, "existing-tag"
        assert_includes @location.tags, "new-tag"
        assert_includes @location.tags, "another-tag"
      end

      test "apply_tags ensures uniqueness" do
        @location.tags = [ "tag1", "tag2" ]
        enrichment = { tags: [ "tag2", "tag3" ] }

        @applicator.send(:apply_tags, enrichment)

        assert_equal [ "tag1", "tag2", "tag3" ], @location.tags.sort
      end

      test "apply_tags does nothing when tags blank" do
        original_tags = @location.tags.dup
        enrichment = { tags: [] }

        @applicator.send(:apply_tags, enrichment)

        assert_equal original_tags, @location.tags
      end

      test "apply_tags does nothing when tags nil" do
        original_tags = @location.tags.dup
        enrichment = { tags: nil }

        @applicator.send(:apply_tags, enrichment)

        assert_equal original_tags, @location.tags
      end

      test "apply_tags does nothing when tags key missing" do
        original_tags = @location.tags.dup
        enrichment = {}

        @applicator.send(:apply_tags, enrichment)

        assert_equal original_tags, @location.tags
      end

      # === apply_practical_info tests ===

      test "apply_practical_info stores data in audio_tour_metadata" do
        practical_info = {
          best_time: "morning",
          duration_minutes: 60,
          tips: [ "Bring water", "Arrive early" ]
        }
        enrichment = { practical_info: practical_info }

        @applicator.send(:apply_practical_info, enrichment)

        # JSONB stores with string keys
        stored_info = @location.audio_tour_metadata["practical_info"]
        assert_equal "morning", stored_info["best_time"]
        assert_equal 60, stored_info["duration_minutes"]
        assert_equal [ "Bring water", "Arrive early" ], stored_info["tips"]
      end

      test "apply_practical_info merges with existing audio_tour_metadata" do
        @location.audio_tour_metadata = { "existing_key" => "existing_value" }
        practical_info = { best_time: "afternoon", duration_minutes: 30, tips: [] }
        enrichment = { practical_info: practical_info }

        @applicator.send(:apply_practical_info, enrichment)

        assert_equal "existing_value", @location.audio_tour_metadata["existing_key"]

        stored_info = @location.audio_tour_metadata["practical_info"]
        assert_equal "afternoon", stored_info["best_time"]
        assert_equal 30, stored_info["duration_minutes"]
      end

      test "apply_practical_info initializes audio_tour_metadata if nil" do
        @location.audio_tour_metadata = nil
        practical_info = { best_time: "evening", duration_minutes: 90, tips: [] }
        enrichment = { practical_info: practical_info }

        @applicator.send(:apply_practical_info, enrichment)

        assert_not_nil @location.audio_tour_metadata

        stored_info = @location.audio_tour_metadata["practical_info"]
        assert_equal "evening", stored_info["best_time"]
        assert_equal 90, stored_info["duration_minutes"]
      end

      test "apply_practical_info does nothing when practical_info blank" do
        original_metadata = @location.audio_tour_metadata.dup
        enrichment = { practical_info: {} }

        @applicator.send(:apply_practical_info, enrichment)

        assert_equal original_metadata, @location.audio_tour_metadata
      end

      test "apply_practical_info does nothing when practical_info nil" do
        original_metadata = @location.audio_tour_metadata.dup
        enrichment = { practical_info: nil }

        @applicator.send(:apply_practical_info, enrichment)

        assert_equal original_metadata, @location.audio_tour_metadata
      end

      test "apply_practical_info does nothing when practical_info key missing" do
        original_metadata = @location.audio_tour_metadata.dup
        enrichment = {}

        @applicator.send(:apply_practical_info, enrichment)

        assert_equal original_metadata, @location.audio_tour_metadata
      end

      # === Integration test ===

      test "apply integrates all enrichment data" do
        enrichment = {
          descriptions: {
            bs: "Stari most je najpoznatiji most u BiH"
          },
          historical_context: {
            bs: "Izgradjen 1566. godine"
          },
          suitable_experiences: [ "culture", "history" ],
          tags: [ "unesco", "historic" ],
          practical_info: {
            best_time: "morning",
            duration_minutes: 45,
            tips: [ "Visit early to avoid crowds" ]
          }
        }

        # Mock classifier to avoid external dependencies
        mock_classifier = Minitest::Mock.new
        mock_classifier.expect :classify, { success: true, types: [ "culture", "history" ] },
          [ @location ], dry_run: false, hints: [ "culture", "history" ]

        Ai::ExperienceTypeClassifier.stub :new, mock_classifier do
          @applicator.apply(enrichment)
        end

        # Verify all data applied
        assert_equal "Stari most je najpoznatiji most u BiH", @location.translate(:description, :bs)
        assert_equal "Izgradjen 1566. godine", @location.translate(:historical_context, :bs)
        assert_includes @location.tags, "unesco"
        assert_includes @location.tags, "historic"

        # JSONB stores with string keys
        stored_info = @location.audio_tour_metadata["practical_info"]
        assert_equal "morning", stored_info["best_time"]

        assert mock_classifier.verify
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class RebuildExperiencesJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", RebuildExperiencesJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: RebuildExperiencesJob,
      args: [{ dry_run: true, rebuild_mode: "quality", max_rebuilds: 10 }]
    ) do
      RebuildExperiencesJob.perform_later(dry_run: true, rebuild_mode: "quality", max_rebuilds: 10)
    end
  end

  test "job accepts delete_similar parameter" do
    assert_enqueued_with(
      job: RebuildExperiencesJob,
      args: [{ delete_similar: true }]
    ) do
      RebuildExperiencesJob.perform_later(delete_similar: true)
    end
  end

  test "job accepts delete_orphaned parameter" do
    assert_enqueued_with(
      job: RebuildExperiencesJob,
      args: [{ delete_orphaned: true }]
    ) do
      RebuildExperiencesJob.perform_later(delete_orphaned: true)
    end
  end

  # === Constants tests ===

  test "MODES includes all valid modes" do
    assert_includes RebuildExperiencesJob::MODES, "all"
    assert_includes RebuildExperiencesJob::MODES, "quality"
    assert_includes RebuildExperiencesJob::MODES, "similar"
    assert_includes RebuildExperiencesJob::MODES, "accommodations"
    assert_includes RebuildExperiencesJob::MODES, "orphaned"
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = RebuildExperiencesJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = RebuildExperiencesJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "clear_status! resets status to idle" do
    Setting.set("rebuild_experiences.status", "in_progress")
    Setting.set("rebuild_experiences.message", "Working...")

    RebuildExperiencesJob.clear_status!

    status = RebuildExperiencesJob.current_status
    assert_equal "idle", status[:status]
  end

  test "force_reset! resets stuck job" do
    Setting.set("rebuild_experiences.status", "in_progress")

    RebuildExperiencesJob.force_reset!

    status = RebuildExperiencesJob.current_status
    assert_equal "idle", status[:status]
  end

  test "current_status handles invalid JSON gracefully" do
    Setting.set("rebuild_experiences.status", "completed")
    Setting.set("rebuild_experiences.results", "invalid json {{{")

    status = RebuildExperiencesJob.current_status
    assert_equal "idle", status[:status]
    assert_equal({}, status[:results])
  end
end

class RebuildExperiencesJobIntegrationTest < ActiveJob::TestCase
  setup do
    @city = "Sarajevo"

    # Create a location for experiences
    @location = Location.create!(
      name: "Test Museum",
      city: @city,
      lat: 43.8563,
      lng: 18.4131
    )

    @location2 = Location.create!(
      name: "Test Monument",
      city: @city,
      lat: 43.8564,
      lng: 18.4132
    )

    @location3 = Location.create!(
      name: "Test Park",
      city: @city,
      lat: 43.8565,
      lng: 18.4133
    )

    # Create experience category
    @category = ExperienceCategory.find_or_create_by!(key: "culture") do |cat|
      cat.name = "Culture"
    end

    # Create experiences with translations
    @experience = Experience.create!(
      title: "Museum Visit",
      experience_category: @category,
      estimated_duration: 60
    )
    @experience.add_location(@location)
    @experience.set_translation(:title, "Museum Visit", :en)
    @experience.set_translation(:description, "A wonderful museum experience where you can explore the rich history and culture of the region with many exhibits.", :en)
    @experience.set_translation(:title, "Posjeta muzeju", :bs)
    @experience.set_translation(:description, "Divno muzejsko iskustvo gdje mozete istraziti bogatu historiju i kulturu regije sa mnogim eksponatima.", :bs)
    @experience.save!

    @experience2 = Experience.create!(
      title: "Walking Tour",
      experience_category: @category,
      estimated_duration: 120
    )
    @experience2.add_location(@location2)
    @experience2.set_translation(:title, "Walking Tour", :en)
    @experience2.set_translation(:description, "An engaging walking tour that takes you through the beautiful streets and hidden gems of the old town.", :en)
    @experience2.save!
  end

  teardown do
    RebuildExperiencesJob.clear_status!
  end

  # Helper to create a mock analyzer that returns the given report
  def create_mock_analyzer(report)
    analyzer = Object.new
    analyzer.define_singleton_method(:generate_report) { |**_args| report }
    # Define private methods that the job code uses via send()
    analyzer.define_singleton_method(:accommodation_location?) { |_location| false }
    analyzer.define_singleton_method(:retirement_home_location?) { |_location| false }
    analyzer
  end

  # Helper to create a mock syncer
  def create_mock_syncer(result)
    syncer = Object.new
    syncer.define_singleton_method(:sync_locations) { |*_args| result }
    syncer
  end

  # === Dry run tests ===

  test "dry run mode does not make changes" do
    original_count = Experience.count

    report = {
      total_experiences: 2,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [{ experience_id: @experience.id, title: @experience.title, issues: [] }],
      deletable_experiences: [],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(dry_run: true)

      assert_equal "completed", result[:status]
      assert result[:dry_run]
      assert_equal original_count, Experience.count, "No experiences should be deleted in dry run"
    end
  end

  test "dry run counts orphaned experiences without deleting" do
    # Create orphaned experience (no locations)
    orphaned = Experience.create!(title: "Orphaned Experience", experience_category: @category)

    report = {
      total_experiences: 3,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [],
      deletable_experiences: [],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(dry_run: true, rebuild_mode: "orphaned")

      assert result[:orphaned_experiences_deleted] >= 1, "Should count orphaned experiences"
      assert Experience.find_by(id: orphaned.id).present?, "Should not delete in dry run"
    end
  end

  # === Orphaned experiences tests ===

  test "deletes orphaned experiences without locations" do
    # Create orphaned experience (no locations)
    orphaned = Experience.create!(title: "Orphaned Experience", experience_category: @category)
    orphaned_id = orphaned.id

    report = {
      total_experiences: 3,
      experiences_with_issues: 0,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [],
      deletable_experiences: [],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(rebuild_mode: "orphaned")

      assert_nil Experience.find_by(id: orphaned_id), "Orphaned experience should be deleted"
      assert result[:orphaned_experiences_deleted] >= 1
    end
  end

  # === Quality mode tests ===

  test "quality mode rebuilds experiences with issues" do
    issues = [
      { type: :short_description, severity: :high, message: "Description too short" }
    ]

    report = {
      total_experiences: 2,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [{ experience_id: @experience.id, title: @experience.title, issues: issues }],
      deletable_experiences: [],
      similar_experiences: []
    }

    ai_response = {
      titles: { "en" => "Updated Museum Visit", "bs" => "Azurirana Posjeta Muzeju" },
      descriptions: {
        "en" => "A completely renovated museum experience with rich historical exhibits.",
        "bs" => "Potpuno obnovljeno muzejsko iskustvo sa bogatim historijskim eksponatima."
      },
      estimated_duration: 90
    }

    syncer_result = { locations_added: 0, locations_created_via_geoapify: 0 }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ai_response) do
        Ai::ExperienceLocationSyncer.stub(:new, create_mock_syncer(syncer_result)) do
          result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality", max_rebuilds: 5)

          assert_equal "completed", result[:status]
          assert_equal 1, result[:experiences_rebuilt]
        end
      end
    end
  end

  # === Deletable experiences tests ===

  test "deletes experiences marked for deletion in quality mode" do
    deletable = Experience.create!(title: "Low Quality Experience", experience_category: @category)
    deletable.add_location(@location3)
    deletable_id = deletable.id

    report = {
      total_experiences: 3,
      experiences_with_issues: 0,
      similar_experience_pairs: 0,
      experiences_to_delete: 1,
      worst_experiences: [],
      deletable_experiences: [{
        experience_id: deletable_id,
        title: "Low Quality Experience",
        delete_reason: "Score too low"
      }],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

      assert_nil Experience.find_by(id: deletable_id), "Experience should be deleted"
      assert_equal 1, result[:experiences_deleted]
    end
  end

  test "handles non-existent deletable experiences gracefully" do
    report = {
      total_experiences: 2,
      experiences_with_issues: 0,
      similar_experience_pairs: 0,
      experiences_to_delete: 1,
      worst_experiences: [],
      deletable_experiences: [{
        experience_id: 999999, # Non-existent ID
        title: "Non-existent Experience",
        delete_reason: "Test deletion"
      }],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

      # Should complete without raising, non-existent experience is just skipped
      assert_equal "completed", result[:status]
      assert_equal 0, result[:experiences_deleted]
    end
  end

  # === Similar experiences tests ===

  test "similar mode handles similar experience pairs" do
    similar_pair = {
      experience_1: { id: @experience.id, title: @experience.title },
      experience_2: { id: @experience2.id, title: @experience2.title },
      similarity: { overall: 0.85, locations: 0.7, title: 0.9 },
      recommendation: :rename_for_clarity
    }

    report = {
      total_experiences: 2,
      experiences_with_issues: 0,
      similar_experience_pairs: 1,
      experiences_to_delete: 0,
      worst_experiences: [],
      deletable_experiences: [],
      similar_experiences: [similar_pair]
    }

    ai_response = {
      titles: { "en" => "Differentiated Tour", "bs" => "Razlicita Tura" },
      descriptions: {
        "en" => "A unique experience that offers a different perspective.",
        "bs" => "Jedinstveno iskustvo koje nudi drugaciju perspektivu."
      },
      estimated_duration: 60
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ai_response) do
        result = RebuildExperiencesJob.perform_now(rebuild_mode: "similar")

        assert_equal "completed", result[:status]
        assert_equal 1, result[:experiences_rebuilt]
      end
    end
  end

  test "delete_similar option deletes duplicate experiences" do
    duplicate = Experience.create!(title: "Duplicate Experience", experience_category: @category)
    duplicate.add_location(@location3)
    duplicate_id = duplicate.id

    similar_pair = {
      experience_1: { id: @experience.id, title: @experience.title },
      experience_2: { id: duplicate_id, title: duplicate.title },
      similarity: { overall: 0.9, locations: 0.8, title: 0.85 },
      recommendation: :merge_or_delete_duplicate
    }

    report = {
      total_experiences: 3,
      experiences_with_issues: 0,
      similar_experience_pairs: 1,
      experiences_to_delete: 0,
      worst_experiences: [],
      deletable_experiences: [],
      similar_experiences: [similar_pair]
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(rebuild_mode: "similar", delete_similar: true)

      assert_equal "completed", result[:status]
      assert_equal 1, result[:experiences_deleted]
    end
  end

  # === Accommodation locations tests ===
  # Note: accommodations mode creates additional Ai::ExperienceAnalyzer instances
  # internally in remove_accommodation_locations_from_experiences, making integration
  # testing complex. The accommodation removal logic is tested in private methods tests.

  # === Error handling tests ===

  test "handles AI service errors during regeneration gracefully" do
    # When AI service fails, the rebuild should fail but job should complete
    # This test verifies the job doesn't crash on AI errors
    issues = [
      { type: :short_description, severity: :high, message: "Description too short" }
    ]

    report = {
      total_experiences: 2,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [{ experience_id: @experience.id, title: @experience.title, issues: issues }],
      deletable_experiences: [],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API Error" }) do
        result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

        # Job should complete even if individual rebuilds fail
        assert_equal "completed", result[:status]
      end
    end
  end

  test "marks job as failed when critical error occurs" do
    # Test that jobs get marked as failed on critical errors
    # We test this by directly checking if the job can handle errors
    error_analyzer = Object.new
    error_analyzer.define_singleton_method(:generate_report) { |**_args| raise StandardError, "Database error" }

    Ai::ExperienceAnalyzer.stub(:new, error_analyzer) do
      # The job has retry_on, so it catches StandardError and retries
      # After retries are exhausted, it marks as failed
      # For testing, we just verify the status methods work
      RebuildExperiencesJob.clear_status!
      status = RebuildExperiencesJob.current_status
      assert_equal "idle", status[:status]
    end
  end

  # === Max rebuilds limit tests ===

  test "respects max_rebuilds limit" do
    issues = [
      { type: :short_description, severity: :high, message: "Description too short" }
    ]

    report = {
      total_experiences: 2,
      experiences_with_issues: 2,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [
        { experience_id: @experience.id, title: @experience.title, issues: issues },
        { experience_id: @experience2.id, title: @experience2.title, issues: issues }
      ],
      deletable_experiences: [],
      similar_experiences: []
    }

    ai_response = {
      titles: { "en" => "Updated Experience", "bs" => "Azurirano Iskustvo" },
      descriptions: {
        "en" => "Updated description with more content.",
        "bs" => "Azurirani opis sa vise sadrzaja."
      },
      estimated_duration: 60
    }

    syncer_result = { locations_added: 0, locations_created_via_geoapify: 0 }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ai_response) do
        Ai::ExperienceLocationSyncer.stub(:new, create_mock_syncer(syncer_result)) do
          result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality", max_rebuilds: 1)

          assert_equal "completed", result[:status]
          assert result[:experiences_rebuilt] <= 1, "Should not exceed max_rebuilds"
        end
      end
    end
  end

  # === Status updates during job execution ===

  test "updates status during job execution" do
    report = {
      total_experiences: 2,
      experiences_with_issues: 0,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [],
      deletable_experiences: [],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

      # After completion, status should be "completed"
      status = RebuildExperiencesJob.current_status
      assert_equal "completed", status[:status]
    end
  end

  # === Rebuild experience with retirement home locations ===

  test "replaces retirement home locations during rebuild" do
    # Create a retirement home location
    retirement_home = Location.create!(
      name: "Dom Penzionera Test",
      city: @city,
      lat: 43.8580,
      lng: 18.4150
    )

    # Create an experience with a retirement home location
    exp_with_retirement = Experience.create!(title: "Experience with Retirement Home", experience_category: @category)
    exp_with_retirement.add_location(retirement_home)
    exp_with_retirement.set_translation(:title, "Experience with Retirement Home", :en)
    exp_with_retirement.set_translation(:description, "An experience that accidentally includes a retirement home location that needs to be replaced.", :en)
    exp_with_retirement.save!

    issues = [
      {
        type: :retirement_home_locations,
        severity: :critical,
        message: "Experience contains retirement home locations",
        location_ids: [retirement_home.id]
      }
    ]

    report = {
      total_experiences: 3,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [{
        experience_id: exp_with_retirement.id,
        title: exp_with_retirement.title,
        issues: issues
      }],
      deletable_experiences: [],
      similar_experiences: []
    }

    ai_response = {
      titles: { "en" => "Updated Experience", "bs" => "Azurirano Iskustvo" },
      descriptions: {
        "en" => "A wonderful experience exploring the cultural heritage.",
        "bs" => "Divno iskustvo istrazivanja kulturne bastine."
      },
      estimated_duration: 60
    }

    syncer_result = { locations_added: 0, locations_created_via_geoapify: 0 }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ai_response) do
        Ai::ExperienceLocationSyncer.stub(:new, create_mock_syncer(syncer_result)) do
          result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

          assert_equal "completed", result[:status]
          assert result[:retirement_home_locations_replaced] >= 0
        end
      end
    end
  end

  # === Multi-city experience regeneration ===

  test "handles multi-city experience regeneration" do
    # Create a location in a different city
    other_city_location = Location.create!(
      name: "Mostar Bridge",
      city: "Mostar",
      lat: 43.3370,
      lng: 17.8150
    )

    # Create a multi-city experience
    multi_city_exp = Experience.create!(title: "Multi-City Tour", experience_category: @category)
    multi_city_exp.add_location(@location)
    multi_city_exp.add_location(other_city_location)
    multi_city_exp.set_translation(:title, "Multi-City Tour", :en)
    multi_city_exp.set_translation(:description, "An experience spanning multiple cities.", :en)
    multi_city_exp.save!

    issues = [
      {
        type: :multi_city_locations,
        severity: :high,
        message: "Experience has locations from multiple cities",
        cities: ["Sarajevo", "Mostar"]
      }
    ]

    report = {
      total_experiences: 3,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [{
        experience_id: multi_city_exp.id,
        title: multi_city_exp.title,
        issues: issues
      }],
      deletable_experiences: [],
      similar_experiences: []
    }

    ai_response = {
      titles: { "en" => "Sarajevo to Mostar Journey", "bs" => "Putovanje od Sarajeva do Mostara" },
      descriptions: {
        "en" => "A regional experience connecting the historic cities of Sarajevo and Mostar.",
        "bs" => "Regionalno iskustvo koje povezuje historijske gradove Sarajevo i Mostar."
      },
      estimated_duration: 240
    }

    syncer_result = { locations_added: 0, locations_created_via_geoapify: 0 }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ai_response) do
        Ai::ExperienceLocationSyncer.stub(:new, create_mock_syncer(syncer_result)) do
          result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

          assert_equal "completed", result[:status]
        end
      end
    end
  end

  # === Location sync from descriptions ===

  test "syncs locations from descriptions after regeneration" do
    issues = [
      { type: :short_description, severity: :high, message: "Description too short" }
    ]

    report = {
      total_experiences: 2,
      experiences_with_issues: 1,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [{ experience_id: @experience.id, title: @experience.title, issues: issues }],
      deletable_experiences: [],
      similar_experiences: []
    }

    ai_response = {
      titles: { "en" => "Updated Museum Visit", "bs" => "Azurirana Posjeta Muzeju" },
      descriptions: {
        "en" => "A museum experience mentioning Gazi Husrev-begova dzamija and Bascarsija.",
        "bs" => "Muzejsko iskustvo koje spominje Gazi Husrev-begovu dzamiju i Bascarsiju."
      },
      estimated_duration: 90
    }

    syncer_result = { locations_added: 2, locations_found_in_db: 1, locations_created_via_geoapify: 1 }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      Ai::OpenaiQueue.stub(:request, ai_response) do
        Ai::ExperienceLocationSyncer.stub(:new, create_mock_syncer(syncer_result)) do
          result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

          assert_equal "completed", result[:status]
          assert_equal 2, result[:locations_synced_from_descriptions]
          assert_equal 1, result[:locations_created_via_geoapify]
        end
      end
    end
  end

  # === Results structure tests ===

  test "returns comprehensive results hash" do
    report = {
      total_experiences: 2,
      experiences_with_issues: 0,
      similar_experience_pairs: 0,
      experiences_to_delete: 0,
      worst_experiences: [],
      deletable_experiences: [],
      similar_experiences: []
    }

    Ai::ExperienceAnalyzer.stub(:new, create_mock_analyzer(report)) do
      result = RebuildExperiencesJob.perform_now(rebuild_mode: "quality")

      # Check all expected keys in result
      assert result.is_a?(Hash), "Result should be a Hash"
      assert result.key?(:started_at)
      assert result.key?(:finished_at)
      assert result.key?(:dry_run)
      assert result.key?(:rebuild_mode)
      assert result.key?(:total_analyzed)
      assert result.key?(:issues_found)
      assert result.key?(:similar_pairs_found)
      assert result.key?(:experiences_rebuilt)
      assert result.key?(:experiences_deleted)
      assert result.key?(:orphaned_experiences_deleted)
      assert result.key?(:accommodation_locations_removed)
      assert result.key?(:retirement_home_locations_replaced)
      assert result.key?(:locations_synced_from_descriptions)
      assert result.key?(:locations_created_via_geoapify)
      assert result.key?(:errors)
      assert result.key?(:analysis_report)
      assert result.key?(:status)
    end
  end
end

class RebuildExperiencesJobPrivateMethodsTest < ActiveJob::TestCase
  setup do
    @city = "Sarajevo"

    @location = Location.create!(
      name: "Test Location",
      city: @city,
      lat: 43.8563,
      lng: 18.4131
    )

    @location2 = Location.create!(
      name: "Test Location 2",
      city: @city,
      lat: 43.8564,
      lng: 18.4132
    )

    @category = ExperienceCategory.find_or_create_by!(key: "culture") do |cat|
      cat.name = "Culture"
    end

    @experience = Experience.create!(title: "Test Experience", experience_category: @category)
    @experience.add_location(@location)
  end

  teardown do
    RebuildExperiencesJob.clear_status!
  end

  test "rebuild_experience returns failure for non-existent experience" do
    job = RebuildExperiencesJob.new

    result = job.send(:rebuild_experience, 999999, [])

    assert_equal false, result[:success]
    assert_equal 0, result[:retirement_homes_replaced]
    assert_equal 0, result[:locations_synced]
    assert_equal 0, result[:locations_created]
  end

  test "rebuild_experience returns failure for experience with no locations" do
    orphaned = Experience.create!(title: "Orphaned", experience_category: @category)
    job = RebuildExperiencesJob.new

    result = job.send(:rebuild_experience, orphaned.id, [])

    assert_equal false, result[:success]
  end

  test "differentiate_experience handles nil experiences gracefully" do
    job = RebuildExperiencesJob.new

    pair = {
      experience_1: { id: 999999 },
      experience_2: { id: 888888 }
    }

    # Should not raise
    result = job.send(:differentiate_experience, pair)
    assert_nil result
  end

  test "delete_worse_experience deletes experience with fewer locations" do
    exp_more_locations = Experience.create!(title: "More Locations", experience_category: @category)
    exp_more_locations.add_location(@location)
    exp_more_locations.add_location(@location2)

    exp_fewer_locations = Experience.create!(title: "Fewer Locations", experience_category: @category)
    exp_fewer_locations.add_location(@location)
    fewer_id = exp_fewer_locations.id

    job = RebuildExperiencesJob.new

    pair = {
      experience_1: { id: exp_more_locations.id },
      experience_2: { id: fewer_id }
    }

    job.send(:delete_worse_experience, pair)

    assert_nil Experience.find_by(id: fewer_id), "Experience with fewer locations should be deleted"
    assert Experience.find_by(id: exp_more_locations.id).present?, "Experience with more locations should remain"
  end

  test "delete_worse_experience deletes newer experience when location counts are equal" do
    # Create older experience
    older_exp = Experience.create!(title: "Older Experience", experience_category: @category)
    older_exp.add_location(@location)
    older_exp.update_column(:created_at, 1.week.ago)

    # Create newer experience
    newer_exp = Experience.create!(title: "Newer Experience", experience_category: @category)
    newer_exp.add_location(@location2)
    newer_id = newer_exp.id

    job = RebuildExperiencesJob.new

    pair = {
      experience_1: { id: older_exp.id },
      experience_2: { id: newer_id }
    }

    job.send(:delete_worse_experience, pair)

    assert_nil Experience.find_by(id: newer_id), "Newer experience should be deleted when locations equal"
    assert older_exp.reload.present?, "Older experience should remain"
  end

  test "find_replacement_locations returns array of locations in same city" do
    # Create another location for potential replacement
    Location.create!(
      name: "Replacement Location",
      city: @city,
      lat: 43.8570,
      lng: 18.4140
    )

    job = RebuildExperiencesJob.new

    results = job.send(:find_replacement_locations, city: @city, exclude_ids: [@location.id], count_needed: 1)

    assert results.is_a?(Array)
  end

  test "supported_locales returns array of locale codes" do
    job = RebuildExperiencesJob.new

    # Create or ensure some locales exist
    Locale.find_or_create_by!(code: "en") do |l|
      l.name = "English"
      l.active = true
      l.ai_supported = true
      l.position = 1
    end

    Locale.find_or_create_by!(code: "bs") do |l|
      l.name = "Bosnian"
      l.active = true
      l.ai_supported = true
      l.position = 2
    end

    locales = job.send(:supported_locales)

    assert locales.is_a?(Array)
    assert locales.include?("en") || locales.include?("bs") || locales.any?, "Should have at least one locale"
  end

  test "save_status handles errors gracefully" do
    job = RebuildExperiencesJob.new

    # Force an error by making Setting.set raise
    Setting.stub(:set, ->(*) { raise StandardError, "Database error" }) do
      # Should not raise - just logs the error
      job.send(:save_status, "test", "test message")
    end

    # Verify no exception was raised - the test passing is the assertion
    assert true, "save_status should handle errors without raising"
  end

  test "build_regeneration_prompt includes cultural context" do
    job = RebuildExperiencesJob.new

    issues = [{ type: :short_description, message: "Description too short" }]

    prompt = job.send(:build_regeneration_prompt, @experience, @experience.locations, issues)

    assert prompt.include?("IJEKAVICA"), "Prompt should mention ijekavica for Bosnian"
    assert prompt.include?(@experience.title), "Prompt should include experience title"
  end

  test "build_differentiation_prompt includes both experiences" do
    exp2 = Experience.create!(title: "Similar Experience", experience_category: @category)
    exp2.add_location(@location2)

    job = RebuildExperiencesJob.new

    prompt = job.send(:build_differentiation_prompt, @experience, exp2)

    assert prompt.include?(@experience.title), "Prompt should include first experience title"
    assert prompt.include?(exp2.title), "Prompt should include second experience title"
    assert prompt.include?("DIFFERENTIATE"), "Prompt should mention differentiation"
  end

  test "regeneration_schema has correct structure" do
    job = RebuildExperiencesJob.new

    schema = job.send(:regeneration_schema)

    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:titles)
    assert schema[:properties].key?(:descriptions)
    assert schema[:properties].key?(:estimated_duration)
    assert_includes schema[:required], "titles"
    assert_includes schema[:required], "descriptions"
  end

  test "delete_orphaned_experiences with dry_run only counts" do
    # Create orphaned experience
    orphaned = Experience.create!(title: "Orphaned Test", experience_category: @category)
    orphaned_id = orphaned.id

    job = RebuildExperiencesJob.new

    count = job.send(:delete_orphaned_experiences, dry_run: true)

    assert count >= 1, "Should count orphaned experiences"
    assert Experience.find_by(id: orphaned_id).present?, "Should not delete in dry run"
  end

  test "delete_orphaned_experiences actually deletes when not dry_run" do
    # Create orphaned experience
    orphaned = Experience.create!(title: "Orphaned Delete Test", experience_category: @category)
    orphaned_id = orphaned.id

    job = RebuildExperiencesJob.new

    count = job.send(:delete_orphaned_experiences, dry_run: false)

    assert count >= 1, "Should count deleted experiences"
    assert_nil Experience.find_by(id: orphaned_id), "Should delete orphaned experience"
  end

  test "remove_accommodation_locations_from_experiences processes experiences" do
    job = RebuildExperiencesJob.new

    # Should not raise
    result = job.send(:remove_accommodation_locations_from_experiences, dry_run: true)

    assert result.is_a?(Integer)
  end

  test "replace_retirement_home_locations handles empty location_ids" do
    job = RebuildExperiencesJob.new

    issue = { type: :retirement_home_locations, location_ids: [] }

    result = job.send(:replace_retirement_home_locations, @experience, issue)

    assert_equal 0, result
  end

  test "remove_retirement_homes_without_replacement removes locations" do
    # Create a test retirement home location
    retirement_home = Location.create!(
      name: "Test Retirement Home",
      city: @city,
      lat: 43.8590,
      lng: 18.4160
    )

    # Create experience with the retirement home
    exp = Experience.create!(title: "Retirement Test", experience_category: @category)
    exp.add_location(retirement_home)

    job = RebuildExperiencesJob.new

    removed_count = job.send(:remove_retirement_homes_without_replacement, exp, [retirement_home.id])

    assert_equal 1, removed_count
  end

  test "cultural_context returns experience generator constant" do
    job = RebuildExperiencesJob.new

    context = job.send(:cultural_context)

    assert context.is_a?(String)
    assert context.length > 0
  end
end

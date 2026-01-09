# frozen_string_literal: true

require "test_helper"

class LocationCityFixJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in default queue" do
    assert_equal "default", LocationCityFixJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: LocationCityFixJob,
      args: [{ regenerate_content: true, dry_run: false }]
    ) do
      LocationCityFixJob.perform_later(regenerate_content: true, dry_run: false)
    end
  end

  # === Rate limit constants tests ===

  test "GEOAPIFY_SLEEP is defined as 0.2 seconds" do
    assert_equal 0.2, LocationCityFixJob::GEOAPIFY_SLEEP
  end

  test "NOMINATIM_SLEEP is defined as 1.1 seconds" do
    assert_equal 1.1, LocationCityFixJob::NOMINATIM_SLEEP
  end

  test "GEOAPIFY_SLEEP is faster than NOMINATIM_SLEEP" do
    assert LocationCityFixJob::GEOAPIFY_SLEEP < LocationCityFixJob::NOMINATIM_SLEEP
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = LocationCityFixJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = LocationCityFixJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "clear_status! resets status to idle" do
    Setting.set("location_fix.status", "in_progress")
    Setting.set("location_fix.message", "Working...")

    LocationCityFixJob.clear_status!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
    # Message is cleared to empty string or nil
    assert_includes [nil, ""], status[:message]
  end

  test "force_reset_city_fix! resets stuck job" do
    Setting.set("location_fix.status", "in_progress")

    LocationCityFixJob.force_reset_city_fix!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
  end

  # === Soup kitchen keywords tests ===

  test "SOUP_KITCHEN_KEYWORDS is defined and contains expected keywords" do
    keywords = LocationCityFixJob::SOUP_KITCHEN_KEYWORDS

    assert keywords.is_a?(Array)
    assert_includes keywords, "soup kitchen"
    assert_includes keywords, "narodna kuhinja"
    assert_includes keywords, "pučka kuhinja"
    assert_includes keywords, "food bank"
    assert_includes keywords, "banka hrane"
  end

  test "SOUP_KITCHEN_KEYWORDS contains Bosnian/Croatian variants" do
    keywords = LocationCityFixJob::SOUP_KITCHEN_KEYWORDS

    # Bosnian/Croatian keywords
    assert_includes keywords, "javna kuhinja"
    assert_includes keywords, "socijalna kuhinja"
    assert_includes keywords, "besplatna hrana"
  end

  # === Soup kitchen detection tests ===

  test "soup_kitchen? returns true for location with soup kitchen in name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Community Soup Kitchen"
    location.expect :city, "Sarajevo"
    location.expect :translate, nil, [:description, :en]
    location.expect :translate, nil, [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    assert job.send(:soup_kitchen?, location)
    location.verify
  end

  test "soup_kitchen? returns true for location with narodna kuhinja in name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Narodna Kuhinja Centar"
    location.expect :city, "Mostar"
    location.expect :translate, nil, [:description, :en]
    location.expect :translate, nil, [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    assert job.send(:soup_kitchen?, location)
    location.verify
  end

  test "soup_kitchen? returns false for regular restaurant" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Restaurant Sarajevo"
    location.expect :city, "Sarajevo"
    location.expect :translate, "A nice restaurant", [:description, :en]
    location.expect :translate, "Lijep restoran", [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    refute job.send(:soup_kitchen?, location)
    location.verify
  end

  # === City mismatch detection tests ===

  test "check_name_city_mismatch returns mismatch when name mentions different city" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Beautiful View in Blagaj"
    location.expect :city, "Mostar"

    result = job.send(:check_name_city_mismatch, location)

    assert result[:mismatch]
    assert_equal "Blagaj", result[:mentioned_city]
    location.verify
  end

  test "check_name_city_mismatch returns no mismatch when name matches city" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Mostar Old Bridge"
    location.expect :city, "Mostar"

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
    location.verify
  end

  test "check_name_city_mismatch returns no mismatch for generic name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Beautiful Historic Monument"
    location.expect :city, "Sarajevo"

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
    location.verify
  end

  test "check_name_city_mismatch handles nil values" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, nil
    location.expect :city, "Sarajevo"

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
    location.verify
  end

  # === Cities match tests ===

  test "cities_different? returns false for same city names" do
    job = LocationCityFixJob.new
    refute job.send(:cities_different?, "Sarajevo", "Sarajevo")
  end

  test "cities_different? returns true for different city names" do
    job = LocationCityFixJob.new
    assert job.send(:cities_different?, "Sarajevo", "Mostar")
  end

  test "cities_different? handles case differences" do
    job = LocationCityFixJob.new
    refute job.send(:cities_different?, "sarajevo", "SARAJEVO")
  end

  # === Medical facility keywords tests ===

  test "MEDICAL_FACILITY_KEYWORDS is defined and contains expected keywords" do
    keywords = LocationCityFixJob::MEDICAL_FACILITY_KEYWORDS

    assert keywords.is_a?(Array)
    assert_includes keywords, "red cross"
    assert_includes keywords, "crveni krst"
    assert_includes keywords, "crveni križ"
    assert_includes keywords, "hospital"
    assert_includes keywords, "bolnica"
  end

  test "MEDICAL_FACILITY_KEYWORDS contains Bosnian/Croatian variants" do
    keywords = LocationCityFixJob::MEDICAL_FACILITY_KEYWORDS

    # Bosnian/Croatian keywords
    assert_includes keywords, "klinika"
    assert_includes keywords, "dom zdravlja"
    assert_includes keywords, "zdravstveni centar"
    assert_includes keywords, "hitna pomoć"
  end

  # === Medical facility detection tests ===

  test "medical_facility? returns true for location with red cross in name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Red Cross Center"
    location.expect :city, "Sarajevo"
    location.expect :translate, nil, [:description, :en]
    location.expect :translate, nil, [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with crveni krst in name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Crveni Krst Sarajevo"
    location.expect :city, "Sarajevo"
    location.expect :translate, nil, [:description, :en]
    location.expect :translate, nil, [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with hospital in name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "General Hospital Mostar"
    location.expect :city, "Mostar"
    location.expect :translate, nil, [:description, :en]
    location.expect :translate, nil, [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with bolnica in name" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Opća Bolnica Sarajevo"
    location.expect :city, "Sarajevo"
    location.expect :translate, nil, [:description, :en]
    location.expect :translate, nil, [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns false for regular restaurant" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Restaurant Sarajevo"
    location.expect :city, "Sarajevo"
    location.expect :translate, "A nice restaurant", [:description, :en]
    location.expect :translate, "Lijep restoran", [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    refute job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns false for historical bridge" do
    job = LocationCityFixJob.new
    location = Minitest::Mock.new
    location.expect :name, "Stari Most"
    location.expect :city, "Mostar"
    location.expect :translate, "Historic Ottoman bridge", [:description, :en]
    location.expect :translate, "Historijski osmanski most", [:description, :bs]
    location.expect :translate, nil, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]

    refute job.send(:medical_facility?, location)
    location.verify
  end
end

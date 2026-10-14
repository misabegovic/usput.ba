# frozen_string_literal: true

require "test_helper"
require "rake"

class AudioToursRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "audio_tours:generate_city" }
    %w[audio_tours:generate_city audio_tours:generate_missing].each { |name| Rake::Task[name].reenable }

    @mostar = Location.create!(name: "Stari most test", city: "Mostar", lat: 43.3373, lng: 17.8150)
    @retired = Location.create!(name: "Retired test", city: "Mostar", lat: 43.3400, lng: 17.8100,
                                archived_at: Time.current)
    @sarajevo = Location.create!(name: "Baščaršija test", city: "Sarajevo", lat: 43.8598, lng: 18.4313)
  end

  test "generate_city sends the city's live places with the asked locale" do
    calls = capture_batches { Rake::Task["audio_tours:generate_city"].invoke("Mostar", "en") }

    locations, locales = calls.sole
    assert_includes locations, @mostar
    assert_not_includes locations, @retired
    assert_not_includes locations, @sarajevo
    assert_equal [ "en" ], locales
  end

  test "generate_missing sends live places without audio in the locale" do
    calls = capture_batches { Rake::Task["audio_tours:generate_missing"].invoke }

    locations, locales = calls.sole
    assert_includes locations, @sarajevo
    assert_not_includes locations, @retired
    assert_equal [ "bs" ], locales
  end

  private

  def capture_batches
    calls = []
    fake = lambda do |locations, locales:, **|
      calls << [ locations.to_a, locales ]
      { generated: 0, skipped: 0, failed: 0, errors: [] }
    end
    Ai::AudioTourGenerator.stub(:generate_batch, fake) do
      assert_output(/Results/) { yield }
    end
    calls
  end
end

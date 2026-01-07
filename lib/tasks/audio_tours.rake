# frozen_string_literal: true

namespace :audio_tours do
  desc "Generate audio tour for a specific location"
  task :generate, [:location_id, :locale] => :environment do |_t, args|
    location_id = args[:location_id]
    locale = args[:locale] || "bs"

    location = Location.find(location_id)
    generator = Ai::AudioTourGenerator.new(location)

    puts "Generating audio tour for: #{location.name}"
    result = generator.generate(locale: locale)

    puts "Result: #{result[:status]}"
    puts "Duration: #{result[:duration_estimate]}" if result[:duration_estimate]
  end

  desc "Generate audio tours for all locations in a city"
  task :generate_city, [:city_id, :locale] => :environment do |_t, args|
    city_id = args[:city_id]
    locale = args[:locale] || "bs"

    city = City.find(city_id)
    locations = city.locations

    puts "Generating audio tours for #{locations.count} locations in #{city.name}"

    result = Ai::AudioTourGenerator.generate_batch(locations, locale: locale)

    puts "\nResults:"
    puts "  Generated: #{result[:generated]}"
    puts "  Skipped (already exist): #{result[:skipped]}"
    puts "  Failed: #{result[:failed]}"

    if result[:errors].any?
      puts "\nErrors:"
      result[:errors].each do |error|
        puts "  - #{error[:location]}: #{error[:error]}"
      end
    end
  end

  desc "Generate audio tours for all locations without audio"
  task generate_missing: :environment do
    locale = ENV.fetch("LOCALE", "bs")
    # Find locations that don't have audio tours with audio files for this locale
    locations_with_audio_ids = AudioTour.by_locale(locale).with_audio.pluck(:location_id)
    locations = Location.where.not(id: locations_with_audio_ids)

    puts "Found #{locations.count} locations without audio tours for locale '#{locale}'"

    result = Ai::AudioTourGenerator.generate_batch(locations, locale: locale)

    puts "\nResults:"
    puts "  Generated: #{result[:generated]}"
    puts "  Failed: #{result[:failed]}"

    if result[:errors].any?
      puts "\nErrors:"
      result[:errors].each do |error|
        puts "  - #{error[:location]}: #{error[:error]}"
      end
    end
  end

  desc "Preview audio tour script (without generating audio)"
  task :preview, [:location_id, :locale] => :environment do |_t, args|
    location_id = args[:location_id]
    locale = args[:locale] || "bs"

    location = Location.find(location_id)
    generator = Ai::AudioTourGenerator.new(location)

    puts "=== Audio Tour Script for: #{location.name} ===\n\n"

    script = generator.generate_tour_script(locale)
    puts script

    word_count = script.split.length
    duration = (word_count / 150.0).round(1)
    puts "\n=== Stats ==="
    puts "Word count: #{word_count}"
    puts "Estimated duration: #{duration} minutes"
  end

  desc "List locations with audio tours"
  task status: :environment do
    total = Location.count
    with_audio = Location.with_audio.count
    without_audio = total - with_audio

    puts "Audio Tour Status:"
    puts "  Total locations: #{total}"
    puts "  With audio tours: #{with_audio} (#{(with_audio.to_f / total * 100).round(1)}%)"
    puts "  Without audio tours: #{without_audio}"

    # Show breakdown by locale
    puts "\nAudio Tours by Locale:"
    AudioTour::SUPPORTED_LOCALES.each do |code, name|
      count = AudioTour.by_locale(code).with_audio.count
      next if count.zero?
      puts "  #{name} (#{code}): #{count}"
    end
  end
end

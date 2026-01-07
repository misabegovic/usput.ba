namespace :ai do
  desc "Generate experiences for a city using AI"
  task :generate, [ :city_name ] => :environment do |_t, args|
    city_name = args[:city_name]

    if city_name.blank?
      puts "Usage: rails ai:generate[city_name]"
      puts "Example: rails ai:generate[Sarajevo]"
      exit 1
    end

    # Resolve coordinates using geocoding
    coordinates = resolve_city_coordinates(city_name)

    unless coordinates
      puts "Could not resolve coordinates for '#{city_name}'."
      puts "Please check the city name and try again."
      exit 1
    end

    puts "Starting AI generation for #{city_name}..."
    puts "Coordinates: #{coordinates[:lat]}, #{coordinates[:lng]}"
    puts "This may take a few minutes depending on the number of places."
    puts

    generator = Ai::ExperienceGenerator.new(city_name, coordinates: coordinates)
    result = generator.generate_all

    puts
    puts "Generation Complete!"
    puts "=" * 50
    puts "City: #{result[:city]}"
    puts "Locations created: #{result[:locations_created]}"
    puts "Experiences created: #{result[:experiences_created]}"
    puts
    puts "Locations:"
    result[:locations]&.each { |name| puts "  - #{name}" }
    puts
    puts "Experiences:"
    result[:experiences]&.each { |title| puts "  - #{title}" }
  end

  desc "Generate experiences for a city in background"
  task :generate_async, [ :city_name ] => :environment do |_t, args|
    city_name = args[:city_name]

    if city_name.blank?
      puts "Usage: rails ai:generate_async[city_name]"
      exit 1
    end

    # Verify we can resolve coordinates
    coordinates = resolve_city_coordinates(city_name)

    unless coordinates
      puts "Could not resolve coordinates for '#{city_name}'."
      exit 1
    end

    AiGenerationJob.perform_later(city_name, generation_type: "full", lat: coordinates[:lat], lng: coordinates[:lng])
    puts "AI generation job enqueued for #{city_name}"
    puts "Check logs or AiGeneration records for progress."
  end

  desc "Generate for cities with existing locations"
  task generate_all: :environment do
    # Get distinct cities that have locations with coordinates
    city_names = Location.where.not(city: [nil, ""])
                         .where.not(lat: nil, lng: nil)
                         .distinct
                         .pluck(:city)

    puts "Found #{city_names.count} cities with existing locations"
    puts "Enqueueing generation jobs..."

    city_names.each_with_index do |city_name, index|
      # Get coordinates from existing location in that city
      location = Location.where(city: city_name).where.not(lat: nil, lng: nil).first
      next unless location

      # Stagger jobs to avoid rate limiting
      AiGenerationJob.set(wait: index * 30.seconds).perform_later(
        city_name,
        generation_type: "full",
        lat: location.lat,
        lng: location.lng
      )
      puts "  [#{index + 1}/#{city_names.count}] Enqueued: #{city_name}"
    end

    puts
    puts "All jobs enqueued. They will run with 30-second intervals."
  end

  desc "Show AI generation status"
  task status: :environment do
    puts "AI Generation Status"
    puts "=" * 60

    AiGeneration.statuses.keys.each do |status|
      count = AiGeneration.where(status: status).count
      puts "#{status.titleize}: #{count}"
    end

    puts
    puts "Recent Generations:"
    AiGeneration.recent.limit(10).each do |gen|
      status_icon = case gen.status
      when "pending" then "⏳"
      when "processing" then "🔄"
      when "completed" then "✅"
      when "failed" then "❌"
      end

      puts "  #{status_icon} #{gen.city_name} (#{gen.generation_type})"
      puts "     Locations: #{gen.locations_created}, Experiences: #{gen.experiences_created}"
      puts "     #{gen.error_message}" if gen.failed?
    end
  end

  desc "Retry failed generations"
  task retry_failed: :environment do
    failed = AiGeneration.failed

    puts "Found #{failed.count} failed generations"

    failed.each do |gen|
      puts "  Retrying: #{gen.city_name}"
      gen.update!(status: :pending, error_message: nil)
      AiGenerationJob.perform_later(gen.city_name, generation_type: gen.generation_type)
    end

    puts "Done. #{failed.count} jobs re-enqueued."
  end

  # ============================================
  # Country-Wide Location Generation Tasks
  # ============================================

  namespace :country do
    desc "Generate locations across ALL of Bosnia and Herzegovina (no city restrictions)"
    task generate_all: :environment do
      puts "🇧🇦 Starting country-wide location generation..."
      puts "This will discover locations across ALL regions of BiH."
      puts "AI will suggest notable places and assign city names."
      puts
      puts "Regions to cover:"
      Ai::CountryWideLocationGenerator::BIH_REGIONS.keys.each do |region|
        puts "  - #{region}"
      end
      puts

      generator = Ai::CountryWideLocationGenerator.new(
        skip_existing: true,
        max_locations_per_region: 20
      )

      result = generator.generate_all

      puts
      puts "=" * 60
      puts "Generation Complete!"
      puts "=" * 60
      puts "Locations created: #{result[:locations_created]}"
      puts
      if result[:locations].any?
        puts "Created locations:"
        result[:locations].each do |loc|
          puts "  - #{loc[:name]} (#{loc[:city] || 'no city'})"
        end
      end
    end

    desc "Generate locations for a specific region"
    task :generate_region, [ :region_name ] => :environment do |_t, args|
      region_name = args[:region_name]

      if region_name.blank?
        puts "Usage: rails ai:country:generate_region[region_name]"
        puts
        puts "Available regions:"
        Ai::CountryWideLocationGenerator::BIH_REGIONS.keys.each do |region|
          puts "  - #{region}"
        end
        exit 1
      end

      unless Ai::CountryWideLocationGenerator::BIH_REGIONS.key?(region_name)
        puts "Unknown region: #{region_name}"
        puts
        puts "Available regions:"
        Ai::CountryWideLocationGenerator::BIH_REGIONS.keys.each do |region|
          puts "  - #{region}"
        end
        exit 1
      end

      puts "🗺️ Generating locations for #{region_name}..."

      generator = Ai::CountryWideLocationGenerator.new(
        skip_existing: true,
        max_locations_per_region: 25
      )

      result = generator.generate_for_region(region_name)

      puts
      puts "Generation Complete!"
      puts "Locations created: #{result[:locations_created]}"
    end

    desc "Generate locations by category (natural, historical, religious, culinary, cultural, adventure)"
    task :generate_category, [ :category ] => :environment do |_t, args|
      category = args[:category]
      valid_categories = %w[natural historical religious culinary cultural adventure]

      if category.blank? || !valid_categories.include?(category)
        puts "Usage: rails ai:country:generate_category[category]"
        puts
        puts "Available categories:"
        valid_categories.each { |c| puts "  - #{c}" }
        exit 1
      end

      puts "🏷️ Generating #{category} locations across BiH..."

      generator = Ai::CountryWideLocationGenerator.new(
        skip_existing: true
      )

      result = generator.generate_by_category(category)

      puts
      puts "Generation Complete!"
      puts "Locations created: #{result[:locations_created]}"
    end

    desc "Discover hidden gems - lesser-known but amazing places"
    task :hidden_gems, [ :count ] => :environment do |_t, args|
      count = (args[:count] || 15).to_i

      puts "💎 Discovering #{count} hidden gems across BiH..."
      puts "Looking for lesser-known places that deserve more attention..."
      puts

      generator = Ai::CountryWideLocationGenerator.new(
        skip_existing: true
      )

      result = generator.discover_hidden_gems(count: count)

      puts
      puts "Discovery Complete!"
      puts "Hidden gems found: #{result[:locations_created]}"
      puts
      if result[:locations].any?
        puts "Discovered gems:"
        result[:locations].each do |loc|
          puts "  💎 #{loc[:name]} (#{loc[:city] || 'rural area'})"
        end
      end
    end

    desc "Show available regions for generation"
    task regions: :environment do
      puts "Available regions for country-wide generation:"
      puts "=" * 50
      Ai::CountryWideLocationGenerator::BIH_REGIONS.each do |name, data|
        puts "#{name}"
        puts "  Center: #{data[:lat]}, #{data[:lng]}"
        puts "  Radius: #{data[:radius] / 1000}km"
        puts
      end
    end
  end

  private

  # Resolve coordinates for a city using existing locations or geocoding
  def resolve_city_coordinates(city_name)
    # First try to get coordinates from existing locations
    location = Location.where(city: city_name).where.not(lat: nil, lng: nil).first
    if location
      return { lat: location.lat, lng: location.lng }
    end

    # Fall back to geocoding
    results = Geocoder.search("#{city_name}, Bosnia and Herzegovina")
    if results.first
      return { lat: results.first.latitude, lng: results.first.longitude }
    end

    nil
  end
end

# Make helper available within rake context
def resolve_city_coordinates(city_name)
  # First try to get coordinates from existing locations
  location = Location.where(city: city_name).where.not(lat: nil, lng: nil).first
  if location
    return { lat: location.lat, lng: location.lng }
  end

  # Fall back to geocoding
  results = Geocoder.search("#{city_name}, Bosnia and Herzegovina")
  if results.first
    return { lat: results.first.latitude, lng: results.first.longitude }
  end

  nil
end

# frozen_string_literal: true

namespace :ai do
  desc "Pokreni autonomno AI generiranje sadržaja"
  task generate: :environment do
    puts "=" * 60
    puts "AI CONTENT GENERATOR"
    puts "=" * 60
    puts

    puts "AI will automatically:"
    puts "  1. Analyze what content is missing"
    puts "  2. Decide which cities to process"
    puts "  3. Fetch locations from Geoapify"
    puts "  4. Enrich with descriptions and translations"
    puts "  5. Create experiences and travel plans"
    puts
    puts "NOTE: Audio tours are NOT generated here (run separately due to API costs)"
    puts

    max_experiences = ENV["MAX_EXPERIENCES"]&.to_i
    if max_experiences
      puts "Max experiences: #{max_experiences}"
    else
      puts "Max experiences: unlimited"
    end
    puts

    print "Starting in 3 seconds... (Ctrl+C to cancel)"
    3.times do
      sleep 1
      print "."
    end
    puts
    puts

    puts "Starting generation..."
    ContentGenerationJob.perform_later(max_experiences: max_experiences)

    puts
    puts "Job queued! Track progress at: /admin/ai"
    puts "=" * 60
  end

  desc "Pokreni AI generiranje sinkrono (za testiranje)"
  task generate_sync: :environment do
    puts "=" * 60
    puts "AI CONTENT GENERATOR (SYNC MODE)"
    puts "=" * 60
    puts

    max_experiences = ENV["MAX_EXPERIENCES"]&.to_i
    if max_experiences
      puts "Max experiences: #{max_experiences}"
    else
      puts "Max experiences: unlimited"
    end
    puts

    orchestrator = Ai::ContentOrchestrator.new(max_experiences: max_experiences)

    begin
      results = orchestrator.generate

      puts
      puts "=" * 60
      puts "GENERATION COMPLETE"
      puts "=" * 60
      puts
      puts "Locations created:    #{results[:locations_created]}"
      puts "Experiences created:  #{results[:experiences_created]}"
      puts "Plans created:        #{results[:plans_created]}"
      puts

      if results[:cities_processed].present?
        puts "Cities processed:"
        results[:cities_processed].each do |city|
          puts "  - #{city[:city]}: #{city[:locations]} loc, #{city[:experiences]} exp, #{city[:plans]} plans"
        end
      end

      if results[:errors].present?
        puts
        puts "Errors:"
        results[:errors].each do |error|
          puts "  - #{error[:city]}: #{error[:error]}"
        end
      end

      puts "=" * 60
    rescue Ai::ContentOrchestrator::GenerationError => e
      puts
      puts "ERROR: #{e.message}"
      puts "=" * 60
      exit 1
    end
  end

  desc "Prikaži trenutno stanje sadržaja"
  task status: :environment do
    puts "=" * 60
    puts "CONTENT STATUS"
    puts "=" * 60
    puts

    stats = Ai::ContentOrchestrator.content_stats

    puts "City                 Locations  Experiences  Plans  Audio"
    puts "-" * 60

    stats[:cities].each do |city_stat|
      city_name = city_stat[:city].to_s.ljust(20)[0..19]
      locations = city_stat[:locations].to_s.rjust(9)
      experiences = city_stat[:experiences].to_s.rjust(12)
      plans = city_stat[:plans].to_s.rjust(6)
      audio = "#{city_stat[:audio]}/#{city_stat[:locations]} (#{city_stat[:audio_coverage]}%)".rjust(15)

      puts "#{city_name} #{locations} #{experiences} #{plans} #{audio}"
    end

    puts "-" * 60
    puts "TOTAL".ljust(20) +
         stats[:totals][:locations].to_s.rjust(9) +
         stats[:totals][:experiences].to_s.rjust(12) +
         stats[:totals][:plans].to_s.rjust(6) +
         stats[:totals][:audio].to_s.rjust(15)

    puts
    puts "=" * 60
  end

  desc "Prikaži status posljednjeg generiranja"
  task last_generation: :environment do
    status = Ai::ContentOrchestrator.current_status

    puts "=" * 60
    puts "LAST GENERATION STATUS"
    puts "=" * 60
    puts

    puts "Status:  #{status[:status]}"
    puts "Message: #{status[:message]}" if status[:message].present?
    puts "Started: #{status[:started_at]}" if status[:started_at].present?

    if status[:results].present?
      puts
      puts "Results:"
      puts "  Locations created:   #{status[:results]['locations_created']}"
      puts "  Experiences created: #{status[:results]['experiences_created']}"
      puts "  Plans created:       #{status[:results]['plans_created']}"
    end

    if status[:plan].present? && status[:plan]["analysis"].present?
      puts
      puts "AI Analysis:"
      puts "  #{status[:plan]['analysis']}"
    end

    puts
    puts "=" * 60
  end

  namespace :audio do
    desc "Generiši audio ture za lokacije bez audio sadržaja"
    task generate: :environment do
      locale = ENV["LOCALE"] || "bs"
      force = ENV["FORCE"] == "true"
      limit = ENV["LIMIT"]&.to_i

      puts "=" * 60
      puts "AUDIO TOUR GENERATOR"
      puts "=" * 60
      puts

      locations = Location.with_coordinates
                          .left_joins(:audio_tours)
                          .where(audio_tours: { id: nil })
                          .distinct

      if limit
        locations = locations.limit(limit)
        puts "Limiting to #{limit} locations"
      end

      total = locations.count
      puts "Locations without audio: #{total}"
      puts "Locale: #{locale}"
      puts "Force regenerate: #{force}"
      puts

      if total == 0
        puts "All locations have audio tours!"
        puts "=" * 60
        exit 0
      end

      # Procjena troška
      est_chars = total * 2000
      est_cost = (est_chars / 1000.0 * 0.30).round(2)
      puts "Estimated characters: #{est_chars.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "Estimated cost: $#{est_cost}"
      puts

      print "Continue? (y/N): "
      confirm = $stdin.gets.chomp.downcase
      unless confirm == "y"
        puts "Cancelled."
        exit 0
      end

      puts
      puts "Starting generation..."
      puts

      AudioTourGenerationJob.perform_later(
        location_ids: locations.pluck(:id),
        locale: locale,
        force: force
      )

      puts "Job queued! Track progress at: /admin/ai/audio_tours"
      puts "=" * 60
    end

    desc "Prikaži statistiku audio tura"
    task status: :environment do
      puts "=" * 60
      puts "AUDIO TOURS STATUS"
      puts "=" * 60
      puts

      total = Location.count
      with_audio = Location.joins(:audio_tours).merge(AudioTour.with_audio).distinct.count
      without_audio = total - with_audio
      coverage = total > 0 ? (with_audio.to_f / total * 100).round(1) : 0

      puts "Total locations:    #{total}"
      puts "With audio:         #{with_audio}"
      puts "Without audio:      #{without_audio}"
      puts "Coverage:           #{coverage}%"
      puts

      # Po gradu
      puts "By city:"
      puts "-" * 40

      Location.distinct.pluck(:city).compact.sort.each do |city|
        city_total = Location.where(city: city).count
        city_audio = Location.where(city: city)
                             .joins(:audio_tours)
                             .merge(AudioTour.with_audio)
                             .distinct.count
        city_coverage = city_total > 0 ? (city_audio.to_f / city_total * 100).round(1) : 0

        puts "  #{city.ljust(20)} #{city_audio}/#{city_total} (#{city_coverage}%)"
      end

      puts "=" * 60
    end
  end
end

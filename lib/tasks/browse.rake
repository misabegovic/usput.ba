namespace :browse do
  desc "Rebuild the entire Browse table from Location, Experience, and Plan records"
  task rebuild: :environment do
    puts "Rebuilding Browse table..."

    start_time = Time.current
    initial_count = Browse.count

    Browse.rebuild_all!

    final_count = Browse.count
    duration = Time.current - start_time

    puts "Browse table rebuilt successfully!"
    puts "  - Initial records: #{initial_count}"
    puts "  - Final records: #{final_count}"
    puts "  - Duration: #{duration.round(2)} seconds"
    puts ""
    puts "Breakdown by type:"
    puts "  - Locations: #{Browse.locations.count}"
    puts "  - Experiences: #{Browse.experiences.count}"
    puts "  - Plans: #{Browse.plans.count}"
  end

  desc "Sync a specific record to Browse (usage: rake browse:sync[Location,123])"
  task :sync, [ :type, :id ] => :environment do |_, args|
    type = args[:type]
    id = args[:id]

    unless type && id
      puts "Usage: rake browse:sync[Type,ID]"
      puts "  Type: Location, Experience, or Plan"
      puts "  ID: The record ID"
      exit 1
    end

    model_class = type.constantize
    record = model_class.find(id)

    Browse.sync_record(record)
    puts "Successfully synced #{type} ##{id} to Browse"
  rescue ActiveRecord::RecordNotFound
    puts "Record not found: #{type} ##{id}"
    exit 1
  rescue NameError
    puts "Invalid type: #{type}. Use Location, Experience, or Plan."
    exit 1
  end

  desc "Show Browse statistics"
  task stats: :environment do
    puts "Browse Statistics"
    puts "=" * 40
    puts "Total records: #{Browse.count}"
    puts ""
    puts "By type:"
    puts "  - Locations: #{Browse.locations.count}"
    puts "  - Experiences: #{Browse.experiences.count}"
    puts "  - Plans: #{Browse.plans.count}"
    puts ""
    puts "By city (top 10):"
    Browse.group(:city_id)
          .count
          .sort_by { |_, count| -count }
          .first(10)
          .each do |city_id, count|
      city_name = city_id ? City.find(city_id).name : "No city"
      puts "  - #{city_name}: #{count}"
    end
  end
end

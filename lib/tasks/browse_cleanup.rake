# frozen_string_literal: true

namespace :browse do
  desc "Clean up orphaned browse entries where the browsable record no longer exists"
  task cleanup: :environment do
    puts "🧹 Starting browse cleanup..."

    # Find orphaned Location browse entries
    location_browse_ids = Browse.where(browsable_type: "Location").pluck(:id, :browsable_id)
    existing_location_ids = Location.pluck(:id)
    orphaned_locations = location_browse_ids.reject { |_bid, lid| existing_location_ids.include?(lid) }

    if orphaned_locations.any?
      orphaned_browse_ids = orphaned_locations.map(&:first)
      puts "  Found #{orphaned_locations.count} orphaned Location browse entries"
      Browse.where(id: orphaned_browse_ids).destroy_all
      puts "  ✅ Deleted #{orphaned_locations.count} orphaned Location entries"
    else
      puts "  ✅ No orphaned Location entries found"
    end

    # Find orphaned Experience browse entries
    experience_browse_ids = Browse.where(browsable_type: "Experience").pluck(:id, :browsable_id)
    existing_experience_ids = Experience.pluck(:id)
    orphaned_experiences = experience_browse_ids.reject { |_bid, eid| existing_experience_ids.include?(eid) }

    if orphaned_experiences.any?
      orphaned_browse_ids = orphaned_experiences.map(&:first)
      puts "  Found #{orphaned_experiences.count} orphaned Experience browse entries"
      Browse.where(id: orphaned_browse_ids).destroy_all
      puts "  ✅ Deleted #{orphaned_experiences.count} orphaned Experience entries"
    else
      puts "  ✅ No orphaned Experience entries found"
    end

    # Find orphaned Plan browse entries
    plan_browse_ids = Browse.where(browsable_type: "Plan").pluck(:id, :browsable_id)
    existing_plan_ids = Plan.pluck(:id)
    orphaned_plans = plan_browse_ids.reject { |_bid, pid| existing_plan_ids.include?(pid) }

    if orphaned_plans.any?
      orphaned_browse_ids = orphaned_plans.map(&:first)
      puts "  Found #{orphaned_plans.count} orphaned Plan browse entries"
      Browse.where(id: orphaned_browse_ids).destroy_all
      puts "  ✅ Deleted #{orphaned_plans.count} orphaned Plan entries"
    else
      puts "  ✅ No orphaned Plan entries found"
    end

    # Find orphaned Moment browse entries
    moment_browse_ids = Browse.where(browsable_type: "Moment").pluck(:id, :browsable_id)
    existing_moment_ids = Moment.pluck(:id)
    orphaned_moments = moment_browse_ids.reject { |_bid, mid| existing_moment_ids.include?(mid) }

    if orphaned_moments.any?
      orphaned_browse_ids = orphaned_moments.map(&:first)
      puts "  Found #{orphaned_moments.count} orphaned Moment browse entries"
      Browse.where(id: orphaned_browse_ids).destroy_all
      puts "  ✅ Deleted #{orphaned_moments.count} orphaned Moment entries"
    else
      puts "  ✅ No orphaned Moment entries found"
    end

    puts "\n📊 Final counts:"
    puts "  Locations: #{Location.count} (Browse: #{Browse.where(browsable_type: 'Location').count})"
    puts "  Experiences: #{Experience.count} (Browse: #{Browse.where(browsable_type: 'Experience').count})"
    puts "  Plans: #{Plan.count} (Browse: #{Browse.where(browsable_type: 'Plan').count})"
    puts "  Moments: #{Moment.publicly_visible.count} (Browse: #{Browse.where(browsable_type: 'Moment').count})"
    puts "\n✨ Browse cleanup complete!"
  end

  desc "Re-sync all browse entries to match current location/experience/moment data"
  task resync: :environment do
    puts "🔄 Re-syncing Browse table with current data..."

    # Re-sync all locations
    puts "\n📍 Syncing Locations..."
    location_count = 0
    Location.includes(:location_categories).find_each do |location|
      Browse.sync_record(location)
      location_count += 1
      print "\r  Synced: #{location_count}" if location_count % 10 == 0
    end
    puts "\n  ✅ Synced #{location_count} locations"

    # Re-sync all experiences
    puts "\n🎯 Syncing Experiences..."
    experience_count = 0
    Experience.find_each do |experience|
      Browse.sync_record(experience)
      experience_count += 1
      print "\r  Synced: #{experience_count}" if experience_count % 10 == 0
    end
    puts "\n  ✅ Synced #{experience_count} experiences"

    puts "\n📸 Syncing Moments..."
    moment_count = 0
    Moment.publicly_visible.includes(:location).find_each do |moment|
      Browse.sync_record(moment)
      moment_count += 1
      print "\r  Synced: #{moment_count}" if moment_count % 10 == 0
    end
    puts "\n  ✅ Synced #{moment_count} moments"

    puts "\n✨ Browse re-sync complete!"
  end

  desc "Show browse vs actual record counts"
  task stats: :environment do
    puts "\n📊 Browse Statistics\n"
    puts "=" * 50

    locations_actual = Location.count
    locations_browse = Browse.where(browsable_type: "Location").count
    locations_diff = locations_browse - locations_actual

    experiences_actual = Experience.count
    experiences_browse = Browse.where(browsable_type: "Experience").count
    experiences_diff = experiences_browse - experiences_actual

    plans_actual = Plan.count
    plans_browse = Browse.where(browsable_type: "Plan").count
    plans_diff = plans_browse - plans_actual

    moments_actual = Moment.publicly_visible.count
    moments_browse = Browse.where(browsable_type: "Moment").count
    moments_diff = moments_browse - moments_actual

    puts "Locations:"
    puts "  Actual:  #{locations_actual}"
    puts "  Browse:  #{locations_browse}"
    puts "  Diff:    #{locations_diff > 0 ? "+#{locations_diff}" : locations_diff}"

    puts "\nExperiences:"
    puts "  Actual:  #{experiences_actual}"
    puts "  Browse:  #{experiences_browse}"
    puts "  Diff:    #{experiences_diff > 0 ? "+#{experiences_diff}" : experiences_diff}"

    puts "\nPlans:"
    puts "  Actual:  #{plans_actual}"
    puts "  Browse:  #{plans_browse}"
    puts "  Diff:    #{plans_diff > 0 ? "+#{plans_diff}" : plans_diff}"

    puts "\nMoments:"
    puts "  Actual:  #{moments_actual}"
    puts "  Browse:  #{moments_browse}"
    puts "  Diff:    #{moments_diff > 0 ? "+#{moments_diff}" : moments_diff}"

    puts "\nTotal Browse: #{Browse.count}"
    puts "=" * 50

    total_orphaned = locations_diff + experiences_diff + plans_diff + moments_diff
    if total_orphaned > 0
      puts "\n⚠️  Found #{total_orphaned} orphaned browse entries"
      puts "Run 'rake browse:cleanup' to remove them"
    else
      puts "\n✅ All browse entries are in sync!"
    end
  end
end

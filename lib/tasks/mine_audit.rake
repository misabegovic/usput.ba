# One-off audit of existing geo content against the mine layer (static
# engine). Report only — nothing is deleted or modified.
namespace :mine_data do
  desc "Audit existing locations against the mine layer (no deletions)"
  task audit_existing: :environment do
    hits = []
    scope = Location.where.not(lat: nil).where.not(lng: nil)
    total = scope.count
    scope.find_each.with_index do |location, i|
      result = MineChecker::PointCheck.call(lat: location.lat, lon: location.lng, content: location)
      hits << location if result.verdict == :blocked
      print "\r  #{i + 1}/#{total}" if $stdout.tty? && (i % 50).zero?
    end
    puts "\nmine_data:audit_existing: #{total} locations checked, #{hits.size} blocked"
    hits.each do |location|
      puts "  Location##{location.id} #{location.name.to_s.truncate(40)} (#{location.lat}, #{location.lng})"
    end
    puts "  Review the list above — nothing was deleted or modified." if hits.any?
  end
end

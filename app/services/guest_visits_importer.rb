# frozen_string_literal: true

# Replays the check-ins a traveller made before they had an account.
#
# A guest's check-ins live on their own device, so nothing reaches us until they
# sign in and there is somewhere to hang them. At that point the device hands
# over the location uuids it collected and each becomes an ordinary PlanVisit on
# the traveller's explore plan — the same row a logged-in check-in writes, on the
# same find-or-create plan, so signing in on a second device adds to the walk
# rather than starting a new one.
#
# Usage:
#   GuestVisitsImporter.new(user: user, payload: profile_data["visited"]).call
#
class GuestVisitsImporter
  # A walk is a few dozen places; anything past this is a malformed or hostile
  # payload, and truncating beats letting it size our queries.
  MAX_VISITS = 500

  attr_reader :imported_count, :errors

  def initialize(user:, payload:)
    @user = user
    @payload = payload
    @imported_count = 0
    @errors = []
  end

  def call
    return self if already_claimed?
    return self if location_uuids.empty?

    import_visits
    self
  rescue StandardError => e
    @errors << e.message
    self
  end

  def success?
    errors.empty?
  end

  private

  # The device's list is the only check-in path that cannot re-verify the 100 m
  # gate, so it is spent once: a walk with no owner. An account that already
  # holds visits has claimed its walk and the server is authoritative from then
  # on — without this, signing out and back in replays the list unbounded and a
  # traveller can mark the country visited from an armchair.
  def already_claimed?
    @user.plan_visits.exists?
  end

  # Three queries whatever the length of the walk: resolve the uuids, read back
  # what the traveller already has, insert the rest in one statement.
  def import_visits
    plan = Plan.explore_bosnia_for(@user)
    location_ids = Location.where(uuid: location_uuids).pluck(:id)
    return if location_ids.empty?

    already_visited = @user.plan_visits.where(plan: plan, location_id: location_ids).pluck(:location_id)
    fresh = location_ids - already_visited
    return if fresh.empty?

    now = Time.current
    rows = fresh.map do |location_id|
      { user_id: @user.id, plan_id: plan.id, location_id: location_id, created_at: now, updated_at: now }
    end

    # unique_by names the same index the model's validation mirrors, so a device
    # replaying a list it already sent is a no-op rather than a violation.
    result = PlanVisit.insert_all(rows, unique_by: %i[user_id plan_id location_id])
    @imported_count = result.count
  end

  def location_uuids
    @location_uuids ||= parsed_payload.filter_map { |entry| uuid_from(entry) }.uniq.first(MAX_VISITS)
  end

  # Untrusted device records: bare uuids or objects, anything else dropped
  # rather than failing a sign-in. Experiences have no PlanVisit, so they go too.
  def uuid_from(entry)
    return entry.strip.presence if entry.is_a?(String)
    return nil unless entry.is_a?(Hash)
    return nil unless entry["type"].nil? || entry["type"] == "location"

    entry["id"].is_a?(String) ? entry["id"].strip.presence : nil
  end

  def parsed_payload
    return @payload if @payload.is_a?(Array)
    return [] if @payload.blank?

    parsed = JSON.parse(@payload.to_s)
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end
end

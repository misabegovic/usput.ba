# frozen_string_literal: true

# Plans walked and places visited before signing in become rows at the door —
# and both doors, sign-in and sign-up, need it.
module SyncsLocalData
  extend ActiveSupport::Concern

  private

  def sync_local_plans(user, payload)
    plans_data = parse_local(payload)
    return [] unless plans_data.is_a?(Array)

    plans_data.filter_map do |plan_data|
      plan = Plan.create_from_local_storage(plan_data, user: user)[:plan]
      plan&.to_local_storage_format if plan&.persisted?
    end
  end

  # The 100 m gate ran in the browser as each check-in happened, so replaying
  # them here is the one path that cannot re-verify. It belongs at the door and
  # nowhere else: anywhere it repeats, the device could write visits nothing
  # ever stood near.
  def merge_local_profile(user, payload)
    profile = parse_local(payload)
    return unless profile.is_a?(Hash)

    GuestVisitsImporter.new(user: user, payload: profile["visited"]).call
    user.merge_travel_profile(profile)
  end

  def parse_local(payload)
    return payload unless payload.is_a?(String)
    return nil if payload.blank?

    JSON.parse(payload)
  rescue JSON::ParserError
    nil
  end
end

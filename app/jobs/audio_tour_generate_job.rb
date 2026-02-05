# frozen_string_literal: true

class AudioTourGenerateJob < ApplicationJob
  queue_as :default

  def perform(location_id:, locale:, requested_by_id:)
    location = Location.find(location_id)
    user = User.find(requested_by_id)

    generator = Ai::AudioTourGenerator.new(location)
    result = generator.generate(locale: locale, force: false)

    CuratorActivity.record(
      user: user,
      action: "audio_tour_generated",
      recordable: location,
      metadata: {
        locale: locale,
        status: result[:status].to_s,
        duration: result.dig(:audio_info, :duration)
      }
    )
  rescue => e
    CuratorActivity.record(
      user: User.find_by(id: requested_by_id),
      action: "audio_tour_generation_failed",
      recordable: Location.find_by(id: location_id),
      metadata: {
        locale: locale,
        error: e.message
      }
    )
    raise # Re-raise for Solid Queue retry
  end
end

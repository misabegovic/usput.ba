# frozen_string_literal: true

module Ai
  # Rate limiter za Geoapify API
  # KRITIČNO: Limit je 5 zahtjeva po sekundi - NIKADA ne prekoračiti!
  class RateLimiter
    GEOAPIFY_RATE_LIMIT = 5 # requests per second
    SLEEP_BETWEEN_BATCHES = 1.1 # seconds (malo više od 1s za sigurnost)

    class << self
      # Izvršava blok za svaki batch item-a, poštujući rate limit
      #
      # @param items [Array] Lista item-a za obradu
      # @yield [Array] Batch item-a (max GEOAPIFY_RATE_LIMIT)
      #
      # @example
      #   RateLimiter.with_geoapify_limit(categories) do |batch|
      #     batch.each { |category| fetch_places(category) }
      #   end
      def with_geoapify_limit(items)
        return if items.blank?

        total_batches = (items.size.to_f / GEOAPIFY_RATE_LIMIT).ceil

        items.each_slice(GEOAPIFY_RATE_LIMIT).each_with_index do |batch, index|
          yield batch

          # Sleep između batch-eva, ali ne nakon posljednjeg
          if index < total_batches - 1
            Rails.logger.debug "[AI::RateLimiter] Sleeping #{SLEEP_BETWEEN_BATCHES}s before next batch (#{index + 1}/#{total_batches})"
            sleep(SLEEP_BETWEEN_BATCHES)
          end
        end
      end

      # Izvršava pojedinačni zahtjev sa rate limitingom
      # Koristi se kada treba kontrolirati pojedinačne zahtjeve
      #
      # @param delay [Float] Vrijeme čekanja između zahtjeva (default: 0.2s za 5 req/s)
      def with_delay(delay: 0.2)
        result = yield
        sleep(delay)
        result
      end
    end
  end
end

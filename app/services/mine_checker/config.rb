# Mine Checker configuration access (docs/mine_checker/SPEC.md §4).
# Values come from config/mine_checker.yml with an optional override in
# Rails credentials under `mine_checker:`. Never tuned in code.
module MineChecker
  class Config
    class << self
      def buffer_m = fetch(:buffer_m).to_i

      def staleness_days = fetch(:staleness_days).to_i

      # [lon_min, lat_min, lon_max, lat_max]
      def bih_bbox = fetch(:bih_bbox).map(&:to_f)

      def reset! = @yaml = nil

      private

      def fetch(key)
        credentials_override(key) || yaml.fetch(key.to_s)
      end

      def credentials_override(key)
        Rails.application.credentials.dig(:mine_checker, key)
      end

      def yaml
        @yaml ||= Rails.application.config_for(:mine_checker).stringify_keys
      end
    end
  end
end

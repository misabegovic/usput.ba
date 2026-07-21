# Shared core for point/route mine checks (docs/mine_checker/SPEC.md §5),
# running against the static engine (MineChecker::StaticIndex) — no database
# geometry involved. Design constraints encoded here, not just documented:
# - Fail-closed on MISSING data: without artifacts the verdict is
#   :data_stale (a block), never a pass. Old data does NOT block (owner
#   decision 2026-07-21: the mine picture changes slowly) — checks run
#   normally and every result carries the snapshot date as the caveat.
# - The danger mask is built exclusively from the suspected layer, dilated
#   conservatively; cleared/lifted layers never soften a verdict.
# - Every check writes a MineCheckAudit row, passed and blocked alike.
# - The only positive verdict is :no_known_intersections — never "safe".
module MineChecker
  class BaseCheck
    class << self
      def call(content: nil, **kwargs)
        new(**kwargs).call(content:)
      end
    end

    def call(content: nil)
      result = perform
      audit(result, content)
      result
    end

    private

    # True when the geometry lies entirely outside the BiH bbox.
    def out_of_coverage?
      raise NotImplementedError
    end

    # True when the geometry touches the danger band (subclass responsibility).
    def dangerous?
      raise NotImplementedError
    end

    def index
      StaticIndex.instance
    end

    def perform
      return result(:out_of_coverage) if out_of_coverage?

      as_of = index.available? ? index.data_as_of : nil
      return result(:data_stale, data_as_of: as_of) if as_of.nil?

      if dangerous?
        result(:blocked, matches: [ { band: "danger" } ], data_as_of: as_of)
      else
        result(:no_known_intersections, data_as_of: as_of)
      end
    end

    def bbox_contains?(lat, lon)
      lon_min, lat_min, lon_max, lat_max = Config.bih_bbox
      lon >= lon_min && lon <= lon_max && lat >= lat_min && lat <= lat_max
    end

    def result(verdict, matches: [], data_as_of: nil)
      Result.new(
        verdict:,
        matches:,
        data_as_of: data_as_of || (index.available? ? index.data_as_of : nil),
        checked_at: Time.current
      )
    end

    # Every check is recorded — match details live only here, never in
    # user-facing output (SPEC §6).
    def audit(result, content)
      MineCheckAudit.create!(
        content_type: content&.class&.name,
        content_id: content.respond_to?(:id) ? content.id : nil,
        verdict: result.verdict.to_s,
        matches: result.matches,
        data_as_of: result.data_as_of,
        created_at: result.checked_at
      )
    rescue StandardError => e
      Rails.logger.error("[mine_checker] audit write failed: #{e.class}: #{e.message}")
    end
  end
end

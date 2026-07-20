# Shared core for point/route mine checks (docs/mine_checker/SPEC.md §5).
#
# Design constraints encoded here, not just documented:
# - Fail-closed: missing or stale data yields :data_stale, never a pass.
# - Only kind='suspected' drives the verdict. Cleared/lifted layers must
#   never soften it.
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

    # WKT of the geometry under test (subclass responsibility).
    def wkt
      raise NotImplementedError
    end

    # True when the geometry lies entirely outside the BiH bbox.
    def out_of_coverage?
      raise NotImplementedError
    end

    def perform
      return result(:out_of_coverage) if out_of_coverage?

      as_of = MineArea.suspected.maximum(:data_as_of)
      return result(:data_stale, data_as_of: as_of) if stale?(as_of)

      matches = suspected_matches
      if matches.any?
        result(:blocked, matches:, data_as_of: as_of)
      else
        result(:no_known_intersections, data_as_of: as_of)
      end
    end

    # Fail-closed: no data at all counts as stale.
    def stale?(as_of)
      as_of.nil? || Date.current - as_of > Config.staleness_days
    end

    def suspected_matches
      sql = <<~SQL
        SELECT kind, file_id,
               ST_Distance(geom, ST_GeogFromText(:wkt)) AS distance_m
        FROM mine_areas
        WHERE kind = 'suspected'
          AND ST_DWithin(geom, ST_GeogFromText(:wkt), :buffer_m)
        ORDER BY distance_m ASC
      SQL
      MineArea.connection.select_all(
        ActiveRecord::Base.sanitize_sql([ sql, { wkt:, buffer_m: Config.buffer_m } ])
      ).map do |row|
        { kind: row["kind"], file_id: row["file_id"], distance_m: row["distance_m"].to_f.round(1) }
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
        data_as_of: data_as_of || MineArea.maximum(:data_as_of),
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

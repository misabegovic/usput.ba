module MineChecker
  # Point-band verdicts against the live PostGIS dataset. Shared by the
  # public check endpoint and the static-engine comparison task.
  module Bands
    DANGER_M = 500
    CAUTION_M = 2000

    module_function

    # "danger" | "caution" | "no_known" — assumes the point is inside the
    # coverage bbox and data exists (callers handle those states).
    def db_band_at(lat, lon)
      pt = "SRID=4326;POINT(#{lon} #{lat})"
      min_distance = MineArea.suspected
        .where("ST_DWithin(geom, ST_GeogFromText(:pt), :radius)", pt: pt, radius: CAUTION_M)
        .pick(Arel.sql(ActiveRecord::Base.sanitize_sql([ "MIN(ST_Distance(geom, ST_GeogFromText(?)))", pt ])))

      if min_distance.nil?
        "no_known"
      elsif min_distance <= DANGER_M
        "danger"
      else
        "caution"
      end
    end
  end
end

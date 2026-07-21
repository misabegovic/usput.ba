# Minolovac — classic minesweeper played over scenic static-map backdrops of
# Bosnia and Herzegovina. Mine placement is random and fictional, generated
# client-side per game — it never reflects real mine locations. Real data
# appears only as coarse aggregates: baked-in regional statistics, or a
# single 5 km aggregate query for custom-point boards (no geometry).
class MinesweeperController < ApplicationController
  # suspected_km2: aggregate area of mine-suspected polygons within 30 km of
  # the region center, computed OFFLINE from the vendored 2024-07-31 snapshot.
  REGIONS = {
    "sarajevo" => { name: "Sarajevo", lat: 43.8563, lon: 18.4131, zoom: 12, suspected_km2: 102.3 },
    "mostar" => { name: "Mostar", lat: 43.3438, lon: 17.8078, zoom: 12, suspected_km2: 41.8 },
    "banja-luka" => { name: "Banja Luka", lat: 44.7722, lon: 17.1910, zoom: 12, suspected_km2: 5.2 },
    "jajce" => { name: "Jajce", lat: 44.3420, lon: 17.2703, zoom: 13, suspected_km2: 62.4 },
    "una" => { name: "NP Una", lat: 44.8169, lon: 15.8708, zoom: 11, suspected_km2: 51.9 },
    "sutjeska" => { name: "NP Sutjeska", lat: 43.3350, lon: 18.6900, zoom: 11, suspected_km2: 3.7 }
  }.freeze

  DIFFICULTIES = {
    "easy" => { rows: 9, cols: 9, mines: 10 },
    "medium" => { rows: 12, cols: 12, mines: 24 },
    "hard" => { rows: 14, cols: 14, mines: 40 }
  }.freeze

  # Official BHMAC country-wide figure (822.87 km², rounded) — the one number
  # not derived from our snapshot.
  COUNTRY_SUSPECTED_KM2 = 823
  SNAPSHOT_AREA_COUNT = 11_068

  CUSTOM_RADIUS_M = 5_000

  # Custom boards are educational: playable ONLY where real data records a
  # suspected area nearby (matches the checker's caution radius).
  PLAYABLE_RADIUS_M = 2_000

  # Mine density mirrors the location's real contamination statistics:
  # 0.75x the base count for the least-affected up to 1.25x for the
  # most-affected, capped at 30% of the board. `scale` is the km² that counts
  # as maximum density (100 for the 30 km regional aggregates, 15 for the
  # 5 km custom-point aggregates).
  def self.mines_for(difficulty, region)
    scale = region[:scale] || 100.0
    factor = 0.75 + 0.5 * [ [ region[:suspected_km2] / scale, 1.0 ].min, 0.05 ].max
    [ (difficulty[:mines] * factor).round, difficulty[:rows] * difficulty[:cols] * 3 / 10 ].min
  end

  def show
    if params[:lat].present? && params[:lon].present?
      lat = params[:lat].to_f
      lon = params[:lon].to_f
      return redirect_to minesweeper_path unless bbox_contains?(lat, lon)

      @region_slug = "custom"
      @unplayable = !suspected_nearby?(lat, lon)
      @region = {
        name: "#{lat.round(4)}, #{lon.round(4)}",
        lat: lat, lon: lon, zoom: 14,
        suspected_km2: @unplayable ? 0.0 : local_suspected_km2(lat, lon), scale: 15.0
      }
    elsif params[:region].present? && !REGIONS.key?(params[:region])
      return redirect_to minesweeper_path
    else
      @region_slug = params[:region] || "sarajevo"
      @region = REGIONS[@region_slug]
    end

    @level = DIFFICULTIES.key?(params[:level]) ? params[:level] : "easy"
    @difficulty = DIFFICULTIES[@level]
    @mines = self.class.mines_for(@difficulty, @region)
  end

  private

  def suspected_nearby?(lat, lon)
    MineArea.suspected
      .where("ST_DWithin(geom, ST_GeogFromText(:pt), :r)",
             pt: "SRID=4326;POINT(#{lon} #{lat})", r: PLAYABLE_RADIUS_M)
      .exists?
  end

  # A single aggregate (km² within 5 km) to scale the fictional board's
  # density. No geometry.
  def local_suspected_km2(lat, lon)
    (MineArea.suspected
      .where("ST_DWithin(geom, ST_GeogFromText(:pt), :r)",
             pt: "SRID=4326;POINT(#{lon} #{lat})", r: CUSTOM_RADIUS_M)
      .sum(Arel.sql("ST_Area(geom)")) / 1_000_000.0).round(1)
  end

  def bbox_contains?(lat, lon)
    west, south, east, north = MineChecker::Config.bih_bbox
    lon.between?(west, east) && lat.between?(south, north)
  end
end

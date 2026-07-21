# Educational minesweeper over real map tiles (owner decision 2026-07-21,
# documented in docs/mine_checker/README.md). The board is a geographic grid
# and mines sit EXACTLY on cells that intersect recorded mine-suspected
# areas from the vendored snapshot — the same generalized public layer the
# checker map already displays, downsampled to grid cells. An empty cell
# means only "no recorded area here" and the page says so loudly; it is
# never a safety statement.
class MinesweeperController < ApplicationController
  # Region boards are anchored on the largest recorded suspected area within
  # 30 km of each city (computed offline from the snapshot) so every preset
  # board contains real mines. suspected_km2 = aggregate within 30 km of the
  # original city center, for the educational facts.
  REGIONS = {
    "sarajevo" => { name: "Sarajevo", lat: 44.0181, lon: 18.4106, suspected_km2: 102.3 },
    "mostar" => { name: "Mostar", lat: 43.5322, lon: 17.9713, suspected_km2: 41.8 },
    "banja-luka" => { name: "Banja Luka", lat: 44.5419, lon: 17.0952, suspected_km2: 5.2 },
    "jajce" => { name: "Jajce", lat: 44.3937, lon: 17.2329, suspected_km2: 62.4 },
    "una" => { name: "NP Una", lat: 44.8466, lon: 16.0245, suspected_km2: 51.9 },
    "sutjeska" => { name: "NP Sutjeska", lat: 43.5190, lon: 18.6322, suspected_km2: 3.7 }
  }.freeze

  # cell_m: real-world size of one grid cell. Bigger cells on easy = a wider
  # piece of terrain per decision.
  DIFFICULTIES = {
    "easy" => { rows: 9, cols: 9, cell_m: 150 },
    "medium" => { rows: 12, cols: 12, cell_m: 125 },
    "hard" => { rows: 14, cols: 14, cell_m: 100 }
  }.freeze

  # Official BHMAC country-wide figure (822.87 km², rounded) — the one number
  # not derived from our snapshot.
  COUNTRY_SUSPECTED_KM2 = 823
  SNAPSHOT_AREA_COUNT = 11_068

  CUSTOM_RADIUS_M = 5_000

  def show
    if params[:lat].present? && params[:lon].present?
      lat = params[:lat].to_f
      lon = params[:lon].to_f
      return redirect_to minesweeper_path unless bbox_contains?(lat, lon)

      @region_slug = "custom"
      @region = {
        name: "#{lat.round(4)}, #{lon.round(4)}",
        lat: lat, lon: lon,
        suspected_km2: params[:engine] == "static" ? MineChecker::StaticIndex.instance.suspected_km2_within(lat, lon, CUSTOM_RADIUS_M) : local_suspected_km2(lat, lon),
        scale: 15.0
      }
    elsif params[:region].present? && !REGIONS.key?(params[:region])
      return redirect_to minesweeper_path
    else
      @region_slug = params[:region] || "sarajevo"
      @region = REGIONS[@region_slug]
    end

    @level = DIFFICULTIES.key?(params[:level]) ? params[:level] : "easy"
    @difficulty = DIFFICULTIES[@level]

    @dlat = @difficulty[:cell_m] / 111_320.0
    @dlon = @difficulty[:cell_m] / (111_320.0 * Math.cos(@region[:lat] * Math::PI / 180))
    @south = @region[:lat] - @difficulty[:rows] * @dlat / 2
    @west = @region[:lon] - @difficulty[:cols] * @dlon / 2

    @engine = params[:engine] == "static" ? "static" : "db"
    @mine_cells = @engine == "static" ? static_mine_cells : mine_cells
    # Educational contract: no recorded areas on the board => nothing to
    # learn here => not playable. Pick a point on/near the red areas.
    @unplayable = @mine_cells.empty?
  end

  private

  # One cell is a mine iff its geographic rectangle intersects a recorded
  # suspected area — the board is a downsampling of the public overlay layer.
  def mine_cells
    cache_key = "minesweeper/board/#{@region[:lat].round(4)}/#{@region[:lon].round(4)}/#{@level}"
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      sql = ActiveRecord::Base.sanitize_sql([ <<~SQL, { rmax: @difficulty[:rows] - 1, cmax: @difficulty[:cols] - 1, south: @south, west: @west, dlat: @dlat, dlon: @dlon } ])
        SELECT r, c
        FROM generate_series(0, :rmax) AS r, generate_series(0, :cmax) AS c
        WHERE EXISTS (
          SELECT 1 FROM mine_areas
          WHERE kind = 'suspected'
            AND ST_Intersects(geom, ST_MakeEnvelope(
              :west + c * :dlon, :south + r * :dlat,
              :west + (c + 1) * :dlon, :south + (r + 1) * :dlat, 4326)::geography)
        )
      SQL
      ActiveRecord::Base.connection.select_rows(sql).map { |r, c| [ r.to_i, c.to_i ] }
    end
  end

  def static_mine_cells
    MineChecker::StaticIndex.instance.mine_cells(
      south: @south, west: @west, dlat: @dlat, dlon: @dlon,
      rows: @difficulty[:rows], cols: @difficulty[:cols]
    )
  end

  # Aggregate (km² within 5 km) for the educational facts. No geometry.
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

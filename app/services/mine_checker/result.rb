# Immutable result of a mine check (docs/mine_checker/SPEC.md §5).
#
# Verdicts:
#   :blocked                 — intersects or is within buffer of ≥1 suspected area
#   :no_known_intersections  — no known intersections. NEVER call this "safe":
#                              absence of known intersections is not a guarantee
#                              that an area is mine-free.
#   :data_stale              — dataset older than the staleness threshold (or
#                              missing). Fail-closed: treated as a block.
#   :out_of_coverage         — geometry outside the BiH bbox; check skipped.
module MineChecker
  Result = Struct.new(:verdict, :matches, :data_as_of, :checked_at, keyword_init: true) do
    def blocked? = verdict == :blocked || verdict == :data_stale
  end
  Result.freeze
end

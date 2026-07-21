# One geometry from the mine-contamination dataset (docs/mine_checker/SPEC.md).
# Only kind='suspected' participates in verdicts; cleared/lifted/incident are
# informational layers and must never be used to soften a verdict.
class MineArea < ApplicationRecord
  KINDS = %w[suspected cleared lifted incident].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :source, :data_as_of, :imported_at, presence: true

  scope :suspected, -> { where(kind: "suspected") }
end

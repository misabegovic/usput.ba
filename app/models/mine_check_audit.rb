# Internal audit log of every mine check — blocked and passed alike
# (docs/mine_checker/SPEC.md §6). `matches` carries the geometry details;
# they stay in this table and are never rendered to end users.
class MineCheckAudit < ApplicationRecord
  validates :verdict, presence: true
end

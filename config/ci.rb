# usput's CI, run on the operator's machine: there is no hosted CI
# (wiki/decisions/ci-runs-locally.md). `bin/ci` runs every step below in
# order and stops at the first failure; when all pass, `gh signoff` marks the
# pushed commit green on GitHub.

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: ERB", "npm run lint:erb"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Architecture: enola laws", "bin/enola-gate"
  step "Duplication: exhale dry", "bin/exhale dry --introduced-only"
  step "Review: qualm", "bin/qualm-gate"
  step "Analysis: Roundhouse (report only)", "bin/roundhouse-report"

  step "Brain: tabula validate", "sh -c 'command -v tabula >/dev/null && tabula validate || echo \"tabula: not asked (not installed)\"'"

  # Rebuilt from the schema first: the seed step below leaves rows in the
  # test database, and transactional tests do not clear rows already there.
  step "Tests: Database", "bin/rails db:test:prepare"
  step "Tests: Rails", "env COVERAGE=true bin/rails test"
  step "Tests: System", "bin/rails test:system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  if success?
    step "Signoff: All systems go. Ready for merge.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge.", "Fix the issues and run bin/ci again."
  end
end

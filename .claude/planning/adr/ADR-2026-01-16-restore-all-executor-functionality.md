# ADR: Restore All Executor Functionality

**Date:** 2026-01-16
**Status:** Accepted
**Decision:** Restore all 19 query types to full functionality

## Context

Earlier today (ADR-2026-01-16-executor-simplification), we archived 13 query types to `future/` folder, keeping only 6 active. After discussion, the decision is to restore ALL functionality immediately.

## Decision

Restore all executor functionality by extracting archived code into proper modules:

### Module Structure

```
lib/platform/dsl/
├── executor.rb              # Main dispatcher (~200 lines)
├── executors.rb             # Module autoloads
└── executors/
    ├── schema.rb            # schema_query (existing)
    ├── table_query.rb       # table_query (existing)
    ├── infrastructure.rb    # infrastructure_query, logs_query (existing)
    ├── prompts.rb           # prompts_query, improvement, prompt_action (existing)
    ├── content.rb           # NEW: mutation, generation, audio
    ├── curator.rb           # NEW: proposals, applications, approval, curator_management, curators_query
    ├── knowledge.rb         # NEW: summaries_query, clusters_query
    └── external.rb          # NEW: external_query, code_query
```

### Query Types by Module

| Module | Query Types |
|--------|-------------|
| Schema | schema_query |
| TableQuery | table_query |
| Infrastructure | infrastructure_query, logs_query |
| Prompts | prompts_query, improvement, prompt_action |
| Content | mutation, generation, audio |
| Curator | proposals_query, applications_query, approval, curators_query, curator_management |
| Knowledge | summaries_query, clusters_query |
| External | external_query, code_query |

## Consequences

- All 19 query types will be functional
- Code remains organized in focused modules
- Legacy file in `future/` can be deleted after migration
- All tests should be re-enabled

## Implementation

1. Create Content, Curator, Knowledge, External modules
2. Extract relevant methods from legacy file
3. Update executor.rb to delegate to new modules
4. Update executors.rb with new autoloads
5. Re-enable all skipped tests
6. Delete legacy file after verification

## References

- Previous ADR: ADR-2026-01-16-executor-simplification.md
- Legacy code: lib/platform/dsl/executors/future/executor_legacy.rb

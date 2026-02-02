# ADR: Executor Simplification

**Date:** 2026-01-16
**Status:** Proposed
**Decision:** Simplify executor.rb by extracting unused query types

## Context

The `Platform::DSL::Executor` has grown to:
- 3001 lines
- 140 methods
- 19 query types
- 125+ case branches

Analysis shows only **6 of 19 query types are used in production**:
1. `schema_query` - stats, describe, health
2. `table_query` - dynamic queries with filters
3. `infrastructure_query` - system health
4. `prompts_query` - prompt management
5. `logs_query` - log viewing
6. `improvement` - prepare feature

The other 13 query types are:
- Implemented but not documented to LLM
- Only tested in unit tests
- Planned for "future" phases but not needed now

## Decision

### Option 1: Extract to Feature Modules (Recommended)

Split executor into focused modules:

```
lib/platform/dsl/
├── executor.rb           # Core (~500 lines) - only 6 used types
├── executors/
│   ├── schema.rb         # schema_query
│   ├── table.rb          # table_query
│   ├── infrastructure.rb # infrastructure_query, logs_query
│   └── prompts.rb        # prompts_query, improvement
└── executors/future/     # Archived for future use
    ├── content.rb        # mutation, generation, audio
    ├── curator.rb        # proposals, applications, approval, management
    ├── knowledge.rb      # summaries, clusters
    └── external.rb       # external_query, code_query
```

Benefits:
- Core executor drops from 3001 to ~500 lines
- Each executor is single-responsibility
- Future features can be added incrementally
- Tests can focus on used functionality

### Option 2: Delete Unused Code

Simply delete the 13 unused query types (~2000 lines).

Pros: Simplest, immediate impact
Cons: Need to re-implement when features are needed

### Option 3: Keep as-is, Improve Tests

Focus on test coverage for existing code.

Pros: No refactoring risk
Cons: Maintains complexity, hard to test God Object

## Consequences

### If we choose Option 1:
- **Effort:** 2-4 hours to extract and reorganize
- **Risk:** Low - modular extraction preserves all code
- **Coverage:** Each module becomes easily testable
- **Undercover issues:** Should drop from 170 to <50

### Migration Path

1. Create `executors/` directory structure
2. Extract each query type to its module
3. Update main executor to delegate
4. Move unused executors to `future/`
5. Update tests to match new structure
6. Delete old tests for unused code (or skip them)

## References

- Brain system prompt explicitly disables complex operations
- Only 6 hardcoded DSL calls in production code
- LLM documentation only covers basic queries

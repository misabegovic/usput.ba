# /commit

Napravi git commit sa dobrom porukom.

**Agent:** Developer

## Korištenje

```
/commit                    # Auto-generate poruku
/commit "Fix login bug"    # Sa custom porukom
/commit --amend            # Amend prethodni commit
```

## Proces

### 1. Provjeri promjene

```bash
git status
git diff --staged
git diff
```

### 2. Stage promjene

```bash
# Specifični fajlovi (preferirano)
git add app/models/location.rb
git add test/models/location_test.rb

# Ili sve (oprezno)
git add -A
```

### 3. Generiši poruku

Format:
```
[Scope] Short description (max 50 chars)

- Bullet point explaining what changed
- Another bullet point
- Why this change was needed

Co-Authored-By: Claude <noreply@anthropic.com>
```

Scopes:
- `[Feature]` - nova funkcionalnost
- `[Fix]` - bug fix
- `[Refactor]` - refaktoring bez promjene ponašanja
- `[Test]` - dodavanje/fixing testova
- `[Docs]` - dokumentacija
- `[Chore]` - maintenance, dependencies
- `[Platform]` - Platform brain promjene
- `[Curator]` - Curator dashboard promjene

### 4. Commit

```bash
git commit -m "$(cat <<'EOF'
[Scope] Short description

- Detail 1
- Detail 2

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Primjeri

### Feature
```
[Feature] Add location search with filters

- Implemented full-text search via pg_search
- Added city and type filters
- Created search service for reusability
- Added controller tests

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Fix
```
[Fix] Resolve N+1 query in experiences index

- Added includes(:locations) to controller
- Reduced queries from 50 to 3

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Refactor
```
[Refactor] Extract validation logic to concern

- Created Validatable concern
- Applied to Location and Experience models
- No behavior changes, tests pass

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Output

```
## Commit

### Staged changes
- M app/models/location.rb
- A app/services/search_service.rb
- M test/models/location_test.rb

### Message
[Feature] Add location search

- Implemented SearchService
- Added controller integration
- Added tests

Commit? [y/n]
```

## Pravila

- **Atomic commits** - jedan commit = jedna logička promjena
- **Testirano** - ne commitaj broken kod
- **Jasna poruka** - objasni šta i zašto
- **Ne uključuj** - .env, credentials, large binaries

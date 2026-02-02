# /pr

Kreiraj Pull Request.

**Agent:** Developer

## Korištenje

```
/pr                        # Kreiraj PR za trenutni branch
/pr --draft                # Kreiraj draft PR
/pr --title "Fix bug"      # Sa custom naslovom
```

## Proces

### 1. Provjeri stanje

```bash
# Trenutni branch
git branch --show-current

# Da li je pushed
git status

# Commitovi za PR
git log main..HEAD --oneline
```

### 2. Push ako treba

```bash
git push -u origin $(git branch --show-current)
```

### 3. Analiziraj promjene

```bash
# Diff od main
git diff main...HEAD --stat

# Svi commitovi
git log main..HEAD
```

### 4. Generiši PR

```bash
gh pr create --title "Title" --body "$(cat <<'EOF'
## Summary
- Bullet point 1
- Bullet point 2

## Changes
- `file1.rb`: Description of change
- `file2.rb`: Description of change

## Test plan
- [ ] Test case 1
- [ ] Test case 2

## Screenshots (if UI changes)
N/A

---
🤖 Generated with Claude Code
EOF
)"
```

## PR Template

```markdown
## Summary
[1-3 bullet points opisuju šta PR radi]

## Changes
[Lista fajlova i šta je promijenjeno]

## Test plan
- [ ] Ručno testirano lokalno
- [ ] Unit testovi prolaze
- [ ] Integration testovi prolaze

## Breaking changes
[Da li ima breaking changes? Ako da, koje?]

## Related issues
Closes #123

---
🤖 Generated with Claude Code
```

## Output

```
## Pull Request

### Branch
feature/add-search → main

### Commits (3)
- abc1234 Add SearchService
- def5678 Add controller integration
- ghi9012 Add tests

### Files changed
- 5 files changed
- +150 insertions
- -20 deletions

### PR
Title: [Feature] Add location search
URL: https://github.com/user/repo/pull/45

---
✓ PR created successfully
```

## Draft PR

Za work-in-progress:
```bash
gh pr create --draft --title "[WIP] Feature name"
```

## Pravila

- **Testirano** - svi testovi prolaze
- **Reviewed** - self-review prije submita
- **Focused** - jedna feature/fix po PR
- **Documented** - jasan opis šta i zašto

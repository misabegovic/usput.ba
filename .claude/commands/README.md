# Claude Commands

Skill-ovi za brže izvršavanje zadataka.

## Content komande (koriste DSL)

| Komanda | Agent | Opis |
|---------|-------|------|
| `/quality-audit` | Content Director, Curator | Provjeri kvalitetu sadržaja |
| `/add-location` | Content Director, Curator | Pripremi novu lokaciju |
| `/add-experience` | Content Director, Guide | Pripremi novo iskustvo |
| `/translate` | Content Director | Prevedi sadržaj |
| `/stats` | Curator | Statistike baze (DSL) |

> Content komande koriste Platform DSL za upite, ne direktan Ruby kod.

## Development komande

| Komanda | Agent | Opis |
|---------|-------|------|
| `/cleanup` | Developer | Pronađi i obriši nekorištene fajlove |
| `/compact-docs` | Tech Lead + PM | Kompaktuj planning dokumentaciju |
| `/design` | Tech Lead + PM | Dizajniraj feature ili sistem |
| `/adr` | Tech Lead | Kreiraj Architecture Decision Record |
| `/rfc` | PM + Tech Lead | Request for Comments za veće promjene |
| `/implement` | Developer | Implementiraj feature |
| `/test` | Developer | Napiši ili pokreni testove |
| `/verify` | Developer | Verifikuj da kod radi |
| `/simplify` | Tech Lead + Dev | Pojednostavi kod |
| `/commit` | Developer | Git commit sa dobrom porukom |
| `/pr` | Developer | Kreiraj Pull Request |

## Kako koristiti

```
/stats
/implement "Dodaj search za lokacije"
/commit
```

## Workflow primjer

```
# 1. Dizajniraj feature
/design "User favorites"

# 2. Implementiraj
/implement

# 3. Testiraj
/test

# 4. Verifikuj
/verify

# 5. Commit
/commit

# 6. PR
/pr
```

## Kreiranje novih komandi

1. Kreiraj `.claude/commands/[ime].md`
2. Definiši:
   - Koji agent koristi
   - Šta komanda radi
   - Potrebne inpute
   - Proces izvršavanja
   - Output format

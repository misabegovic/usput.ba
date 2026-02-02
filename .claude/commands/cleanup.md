# /cleanup

Pronađi i obriši nekorištene fajlove u codebase-u.

**Agent:** Developer (ova komanda je izuzetak - radi sa kodom)

## Šta provjeriti

1. **Stimulus kontroleri** - `app/javascript/controllers/`
2. **Partiali** - `app/views/**/`
3. **Jobs** - `app/jobs/`
4. **Services** - `app/services/`
5. **Tmp skripte** - `tmp/*.rb`

## Proces

1. Koristi Explore agenta za analizu
2. Za svaki fajl prikaži:
   - Ime fajla
   - Zašto je kandidat za brisanje
   - Broj linija
3. Pitaj korisnika prije brisanja
4. Pokreni testove za verifikaciju

## Output

```
## Nekorišteni fajlovi

| Fajl | Razlog | Linije |
|------|--------|--------|
| ... | ... | ... |

Obrisati? [y/n]
```

# usput

Usput.ba is a tourism platform for Bosnia and Herzegovina, and this
repository is both the product and its brain. The Rails application lives
where it always has (`app/`, `config/`, `db/`, `lib/`, `test/`). Beside it
sits a knowledge layer that explains what the product is, why it is shaped
the way it is, and where it is going. Humans and agents read the brain
before they change the code, and they update the brain as part of the same
change.

## The three layers

1. **Sources** (`sources/`): raw inputs, immutable. Files here are only ever
   added, never edited or removed. The original Bosnian planning documents
   live under `sources/planning/`. The Mine Checker specification stays at
   `docs/mine_checker/` because the code cites it there.
2. **The wiki** (`wiki/`): English Markdown pages with YAML frontmatter,
   written and kept current by whoever changes the product. Every
   non-trivial claim cites a source: a file under `sources/`, a path in the
   code, or a pull request. `wiki/index.md` is the home page.
3. **This file**: the rules.

The wiki is a derived view. It is never fed back in as a source.

## The contract

The tool is `tabula`, and the contract is `strict` (`contract:` in
`brain.config.yml`). Every page's frontmatter carries `kind`, `sources`,
`status`, `title` and `updated`.

- `kind` is one of reference, initiative, decision, entity, meta, overlap,
  insight, epic, idea, pitch, agent, workflow, architecture.
- `status` is one of draft, living, superseded, archived, proposed,
  accepted, deprecated, suggested.
- `confidence`, when given, is one of high, medium, low.
- `updated` is a real date written YYYY-MM-DD.
- A page that is not a draft cites at least one source under `sources:`.
- Every page is linked from `wiki/index.md` or from an `index.md` in its
  own directory or one above it. A page no index lists is an orphan.
- A decision is an ADR (`## Context`, `## Decision`, `## Alternatives`,
  `## Consequences`). An initiative is a PRD, either in flight (`## What`,
  `## How`, `## Why`, `## Now`, `## Perceived`, `## Target`) or proposed
  (`## Objective`, `## Background`, `## Affected personas`, `## Scope`,
  `## No-gos`, `## Rabbit holes`, `## Appetite`, `## Decision needed`).

`tabula new <kind> <path>` writes a page with all of this in place and lists
it. `tabula validate` names whatever is missing, with its line. Run
`tabula validate` before every commit that touches `wiki/`, `tabula index`
to regenerate `wiki/_views/`, and `tabula intent stamp` after editing a
page. Directories under `wiki/` whose names begin with `_` are reserved for
generated and operational files.

## Where things go

| Shelf | What lives there |
|-------|------------------|
| `wiki/product/` | Purpose, personas, domain vocabulary, the feature inventory. |
| `wiki/architecture/` | How the code is built and why: stack, the Platform DSL, the AI content pipeline, Mine Checker, conventions, frontend. |
| `wiki/decisions/` | ADRs, one decision per page. `log.md` lists them in order. |
| `wiki/initiatives/` | PRDs for work in flight or proposed, and the open issues. |
| `wiki/state.md` | Past, Now, Perceived, Target for the whole product. |
| `wiki/how-we-work.md` | The working method this repository demonstrates. |

## How work flows

1. **Intent first.** Before code moves, find the page that governs it
   (`tabula search <words>`, or the shelf above). If the change departs from
   what a decision or initiative says, amend the page in the same pull
   request, before or alongside the code. Work that nothing governs is a
   question: should it be shaped first?
2. **Decisions are recorded, not remembered.** A choice that a future reader
   would otherwise have to reverse-engineer from the code gets an ADR.
3. **The brain moves with the code.** A pull request that ships a feature
   updates `wiki/product/features.md` and `wiki/state.md`. One that fulfils an
   initiative marks it done in its `## Now`.
4. **Agent-authored content starts at `confidence: low`**, or `medium` when
   every claim cites a file that was read. Humans raise confidence.
5. **Do not invent.** Write "(unknown, needs source)" instead. Dates are
   absolute. Voice is present tense and declarative. No em dashes.

Several agents may work here at once. Take a task with
`tabula claim <task> --as <you>` before starting it, report with
`tabula report --as <you> --kind note --ref <page> --note <text>`, and hand
work back with `tabula sync`, which stops and names the page on a conflict
rather than resolving it.

## Product rules that bind every change

- Tests are mandatory (Minitest). CI runs rubocop, erb_lint and the full
  suite; run the same locally before pushing.
- Follow the patterns the code already uses before inventing new ones.
- AI prompts live in `app/prompts/` as text files, loaded with
  `PromptHelper#load_prompt`, never inline in a service.
- Bosnian content is written in ijekavica ("historija", not "istorija").
  Every interface string exists in both `config/locales/bs.yml` and
  `config/locales/en.yml`; never rely on a Bosnian `default:`.
- Content stays positive and regionally balanced across the whole country,
  and avoids contested modern history (1990 onward).
- Ask when unsure. A question is cheaper than a wrong guess.

## The agent team

Specialised personas live in `.claude/agents/` (written in Bosnian). Load
the persona's file before acting in its role.

| Persona | File | Role |
|---------|------|------|
| Content Director | `content-director.md` | Owns content quality: audits, AI descriptions, translations, making sure experiences have locations. The default for content work. |
| Curator | `curator.md` | Regional balance (FBiH, RS, Brčko; urban and rural) and tourism content quality. |
| Historian | `historian.md` | Historical context from the Illyrians onward, factual, avoiding 1990 onward. |
| Guide | `guide.md` | Practical advice: parking, prices, opening hours, routes. |
| Robert | `robert.md` | Warm, funny storytelling with local expressions. |
| Audio Producer | `audio-producer.md` | Audio tour scripts and ElevenLabs synthesis for premium places. |
| Developer | `developer.md` | Implementation, tests, debugging. |
| Tech Lead | `tech-lead.md` | Architecture, code review, technical decisions. |
| Product Manager | `product-manager.md` | User stories, acceptance criteria, priorities. |

For a task that needs several perspectives, work in multi-persona mode and
tag each contribution: `[PM]`, `[TL]`, `[DEV]`, `[CUR]`, `[HIS]`, `[GUI]`,
`[ROB]`.

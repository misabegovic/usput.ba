# ADR: Uklanjanje Platform baze i konsolidacija na 2 baze

**Datum:** 2026-02-03
**Status:** Prihvaćeno
**Autori:** Muhamed, Claude

## Kontekst

Projekat je imao 3 PostgreSQL baze:
- **primary** - glavna aplikacijska baza
- **queue** - Solid Queue za background jobs
- **platform** - Platform AI (pgvector, knowledge layers, audit logs)

Platform baza je kreirana za:
1. **PlatformAuditLog** - audit trail DSL akcija
2. **PreparedPrompt** - promptovi za fixeve/features
3. **PlatformStatistic** - cache statistika
4. **Knowledge layers** (KnowledgeSummary, KnowledgeCluster, ClusterMembership) - AI sumarizacija sa pgvector embeddingima

## Problem

Nakon analize korištenja, ustanovljeno je da:

1. **Agenti koriste CLI direktno** (`bin/platform exec`), ne API
2. **Audit log se nikad ne čita** - ni od agenata ni od korisnika
3. **PreparedPrompt se ne koristi** - agenti direktno izvršavaju akcije
4. **Knowledge layers se ne koriste** - DSL upiti su dovoljni za pretragu
5. **pgvector/embeddings nisu potrebni** - keyword pretraga je dovoljna

## Odluka

Ukloniti platform bazu potpuno i zadržati samo:
- **primary** - glavna baza
- **queue** - Solid Queue

## Implementacija

### Uklonjeno

**Modeli:**
- PlatformRecord (base class)
- PlatformAuditLog
- PlatformStatistic
- PreparedPrompt
- KnowledgeSummary
- KnowledgeCluster
- ClusterMembership

**DSL Executori:**
- platform/dsl/executors/knowledge.rb
- platform/dsl/executors/prompts.rb

**Knowledge Layer:**
- lib/platform/knowledge/ (cijeli folder)

**Jobs:**
- app/jobs/platform/ (cluster_generation, statistics, summary_generation)

**Migracije:**
- db/platform_migrate/ (cijeli folder)
- db/platform_schema.rb

### Ažurirano

**DSL Executori** (uklonjen audit logging):
- content.rb
- curator.rb
- infrastructure.rb
- schema.rb

**Services:**
- spam_detector.rb (uklonjen audit log)

**Config:**
- database.yml (uklonjena platform sekcija)

## Posljedice

### Pozitivne
- Jednostavnija arhitektura (2 baze umjesto 3)
- Manje održavanja
- Brži testovi (~400 testova manje)
- Nema overhead-a za nekorištene funkcionalnosti

### Negativne
- Nema audit trail-a DSL akcija (prihvatljivo - nije se koristio)
- Nema semantičke pretrage (prihvatljivo - keyword pretraga dovoljna)

## Alternativna razmatranja

1. **Spojiti platform u primary** - odbačeno jer bi zahtijevalo migracije i pgvector u primary
2. **Zadržati samo audit log** - odbačeno jer se ne koristi
3. **Koristiti Rails logger za audit** - moguće dodati kasnije ako bude potrebno

## Statistika

- Uklonjeno: ~15,000+ linija koda
- Testovi: 3635 → 2725 (~900 manje)
- Fajlova: 50+ uklonjeno

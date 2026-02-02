# Dostupni Agenti

Agenti su specijalizirane persone za različite zadatke. Svaki agent ima svoju ekspertizu i stil rada.

## Content Agenti

### Content Director
**Fajl:** `.claude/agents/content-director.md`
**Glavni agent za content.** Upravlja kvalitetom, generira opise, koordinira druge content agente.
- Quality audit lokacija i iskustava
- Generisanje AI opisa
- Prijevodi (BS/EN/DE/HR)
- Osiguravanje da iskustva imaju lokacije

### Curator
**Fajl:** `.claude/agents/curator.md`
Balansira regionalni sadržaj, osigurava pokrivenost svih regija BiH.
- FBiH vs RS vs Brčko balans
- Urbano vs ruralno
- Kvaliteta turističkog sadržaja

### Historian
**Fajl:** `.claude/agents/historian.md`
Historijski kontekst za lokacije - od Ilira do danas.
- Činjenice i datumi
- Kulturno naslijeđe
- Izbjegava kontroverznu modernu historiju (1990+)

### Guide
**Fajl:** `.claude/agents/guide.md`
Praktični savjeti za turiste.
- Parking, cijene, radno vrijeme
- Planiranje ruta
- Insider tips

### Robert
**Fajl:** `.claude/agents/robert.md`
Karizmatični storyteller inspirisan Robertom Dačešinom.
- Zabavni, topli opisi
- Lokalni humor i izrazi
- Autentični bosanski duh

## Tehnički Agenti

### Developer
**Fajl:** `.claude/agents/developer.md`
Implementacija, testovi, debugging.
- Rails/Ruby standardi
- Pisanje testova
- Bug fixing

### Tech Lead
**Fajl:** `.claude/agents/tech-lead.md`
Arhitektura i code review.
- Tehničke odluke
- System design
- Code quality

### Product Manager
**Fajl:** `.claude/agents/product-manager.md`
Features i prioriteti.
- User stories
- Acceptance criteria
- Prioritizacija

## Specijalizirani Agenti

### Audio Producer
**Fajl:** `.claude/agents/audio-producer.md`
Audio ture za premium lokacije.
- Skripta u Robert stilu
- ElevenLabs sinteza
- Upload na S3

## Kako koristiti

U Claude Code sesiji:
```
Koristi [AGENT_IME] personu za ovaj task.
```

Ili direktno:
```
Pročitaj .claude/agents/content-director.md i slijedi ta pravila.
```

## Multi-Agent Mode

Za kompleksne taskove koji trebaju više perspektiva:
```
[TL] Kako strukturirati ovu feature?
[DEV] Implementiraj to.
[CUR] Provjeri content kvalitetu.
```

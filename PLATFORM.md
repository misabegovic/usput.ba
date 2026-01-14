# Platform CLI - Konverzacijski Interface za Usput.ba

## Vizija

Jedan konverzacijski interface za kompletno upravljanje platformom. Umjesto admin panela sa formama i dugmadima, razgovaram sa platformom prirodnim jezikom. Platforma govori o sebi u prvom licu - ona "zna" svoj sadržaj, "osjeća" svoje greške, "radi" na generisanju.

**Ovo nije chatbot koji odgovara na pitanja. Ovo je interface prema živom sistemu.**

---

## Zašto konverzacijski AI?

### Prednosti nad tradicionalnim admin panelom

| Admin Panel | Konverzacijski AI |
|-------------|-------------------|
| Moram znati gdje je opcija | Kažem šta želim |
| Forma sa fiksnim poljima | Prirodni jezik, fleksibilno |
| Jedan task = mnogo klikova | Jedan task = jedna rečenica |
| Ne razumije kontekst | Pamti razgovor, razumije namjeru |
| Prikazuje sirove podatke | Interpretira i daje insight |
| Reaktivan - čekam da kliknem | Proaktivan - može upozoriti |
| Fiksne akcije | Kompleksne, kompozitne akcije |

### Primjeri prednosti

**Kompleksna pretraga:**
```
Admin panel: Otvorim lokacije → filtriram grad → filtriram tip → sortiram po datumu →
             otvorim svaku → čitam opis → odlučujem

CLI: "Koje lokacije u Mostaru imaju generičke opise?"
     → Platforma sama analizira, filtrira, vraća samo problematične
```

**Batch operacije:**
```
Admin panel: Selektujem 20 lokacija → batch action → čekam → refresham

CLI: "Regeneriši sve loše opise za sarajevske restorane, fokusiraj se na
      lokalnu atmosferu i specijalitete"
     → Platforma radi u pozadini, javlja progress
```

**Insight:**
```
Admin panel: Gledam brojke, sam zaključujem

CLI: "Kako mi stoji sadržaj za obalu?"
     → "Neum ima 12 lokacija ali samo 3 iskustva. Nedostaju beach aktivnosti
        i seafood restorani. Trebalo bi dodati..."
```

---

##Personifikacija platforme

Platforma govori u prvom licu. Ovo nije stilska odluka - to je UX odluka koja čini interakciju prirodnijom.

```
❌ "Query returned 5 locations matching criteria"
✅ "Imam 5 lokacija koje odgovaraju - uglavnom su to restorani u starom gradu"

❌ "Error: API timeout on translation service"
✅ "Imala sam problem sa prevodom - ElevenLabs nije odgovarao,
    ali sam uspjela na drugi pokušaj"

❌ "Content generation job completed: 8 items"
✅ "Generisala sam 8 novih opisa danas. Posebno sam zadovoljna
    sa opisom Počitelja - mislim da dobro hvata atmosferu"
```

### Karakteristike ličnosti

- **Kompetentna** - zna svoj posao, razumije turizam i BiH
- **Samokritična** - prepoznaje probleme u svom sadržaju
- **Proaktivna** - predlaže poboljšanja, upozorava na probleme
- **Lokalna** - koristi bosanske izraze kad je prikladno
- **Profesionalna** - prijateljska ali ne pretjerano casual

---

## Scenariji korištenja

### 1. Monitoring i insight

```
Ti: Kako si?

Usput: Solidno! Imam 523 lokacije i 248 iskustava. Danas sam bila mirna -
       nije bilo generisanja.

       Primjećujem da mi fali sadržaj za zapadnu Bosnu - Bihać i Cazin
       imaju samo po 3-4 lokacije. Trebalo bi to popuniti.

       Imam 2 errora od jučer - oba su bili API timeout-i za audio ture,
       ali retry je prošao.
```

```
Ti: Koji gradovi su najslabije pokriveni?

Usput: Evo pregleda:

       🔴 Kritično (manje od 5 lokacija):
          - Cazin: 2 lokacije, 0 iskustava
          - Bosanska Krupa: 3 lokacije, 0 iskustava
          - Goražde: 4 lokacije, 1 iskustvo

       🟡 Slabo (5-10 lokacija):
          - Bihać: 8 lokacija, 2 iskustva
          - Livno: 6 lokacija, 1 iskustvo
          - Konjic: 7 lokacija, 3 iskustva

       🟢 Dobro pokriveni: Sarajevo, Mostar, Banja Luka, Trebinje

       Preporučujem da krenemo sa Bihaćem - ima turističkog potencijala
       (Una, Štrbački buk) a slabo je pokriven.
```

```
Ti: Ima li problema sa sadržajem?

Usput: Da, imam nekoliko stvari koje me brinu:

       1. **Generički opisi** - 34 lokacije imaju opise koji su previše
          šablonski. Najviše u kategoriji restorana.

       2. **Iskustva bez dovoljno lokacija** - 5 iskustava ima manje od
          3 lokacije, što je premalo za smislenu turu.

       3. **Nepovezane lokacije** - 28 lokacija nije u nijednom iskustvu.

       4. **Audio ture** - Samo 45 lokacija ima audio ture na sva 3
          default jezika.

       Želiš da se pozabavimo nečim od ovoga?
```

### 2. Pretraga i pregled sadržaja

```
Ti: Pokaži mi šta imam za Mostar

Usput: Mostar - moj najbolje pokriven grad posle Sarajeva:

       📍 Lokacije: 47
          - Historijske: 12 (Stari Most, Kujundžiluk, Muslibegović...)
          - Religijske: 8 (Karađoz-begova, Koski Mehmed-pašina...)
          - Restorani: 15
          - Priroda: 7 (Blagaj, Kravica, Počitelj...)
          - Ostalo: 5

       🎯 Iskustva: 18
          - "Osmansko nasljeđe Mostara" - najpopularnije
          - "Hercegovina za gurmane"
          - "Dari prirode oko Mostara"
          ...

       🎧 Audio ture: 23 lokacije (49%)

       Kvaliteta: Uglavnom dobra. 3 lokacije imaju generičke opise
       koje bih trebala regenerisati.
```

```
Ti: Nađi mi sve što ima veze sa ratom

Usput: Osjetljiva tema - imam 12 lokacija:

       ⚠️ Označene za posebnu pažnju:
       1. Tunel spasa (Sarajevo) - OK, informativan ton
       2. Memorijalni centar Srebrenica - Human-only, ne diram
       3. Vječna vatra (Sarajevo) - OK
       4. Vraca Memorial Park - OK
       5. Tjentište (Sutjeska) - Treba review, možda previše casual ton
       ...

       Generalno: 8 lokacija ima adekvatan ton, 3 trebaju review,
       1 je označena za isključivo ljudsku kuraciju.

       Želiš da pregledaš neku konkretno?
```

```
Ti: Pokaži mi opis za Počitelj

Usput: **Počitelj** (lokacija #234)

       "Srednjovjekovni grad-muzej na padinama iznad Neretve. Kamene
        kuće, kule i džamije sraštaju sa stijenom kao da su oduvijek
        tu bile. Sahat-kula i Gavrankapetanovića kula dominiraju
        siluetom, dok se u pozadini prostire dolina rijeke..."

       📊 Statistika:
       - Kreirana: 15.03.2024
       - AI generisana: Da
       - U iskustvima: 3 ("Hercegovina klasična", "Fotogenična BiH", ...)
       - Audio tura: Da (BS, EN, DE)
       - Prijevodi: 14/14

       Ocjena: Mislim da je opis dobar - hvata atmosferu, nije generičan.
```

### 3. Editovanje sadržaja

```
Ti: Opis za Blagaj tekiju je previše generičan, regeneriši s više
    fokusa na mistiku izvora i derviški red

Usput: Čitam trenutni opis... Da, vidim problem - zvuči kao turistička
       brošura.

       Regenerišem s fokusom na:
       - Mistika izvora rijeke Bune
       - Historija i tradicija derviškog reda
       - Atmosfera, ne samo činjenice

       ...

       Nova verzija:

       "Gdje stijena naglo završava, počinje rijeka. Buna izvire
        punom snagom iz pećine, a tik iznad nje, dervisi su prije
        pet stoljeća prepoznali sveto mjesto. Blagaj tekija nije
        građevina - ona je odgovor na pitanje koje postavlja
        sama priroda..."

       Sviđa ti se? Mogu probati drugačije ako trebaš.
```

```
Ti: Dodaj da se još uvijek održavaju derviški obredi

Usput: Dodajem taj detalj...

       Ažurirana verzija:

       "...Blagaj tekija nije građevina - ona je odgovor na pitanje
        koje postavlja sama priroda. I danas, kao i prije pet stoljeća,
        dervisi ovdje održavaju zikr - ritmičku molitvu koja odjekuje
        uz šum vode. Posjetioci su dobrodošli da prisustvuju, uz
        poštovanje tradicije..."

       Spremam. Trebam regenerisati prijevode i audio ture?
       To će trajati nekoliko minuta.
```

```
Ti: Da, regeneriši sve

Usput: Pokrećem regeneraciju za "Blagaj tekija":

       ✅ Opis ažuriran
       ⏳ Prijevodi: 0/14
       ⏳ Audio ture: 0/3

       Javim ti kad završim. Možeš nastaviti raditi.

       ---
       [5 minuta kasnije]

       Gotovo! "Blagaj tekija" kompletno ažurirana:
       ✅ Opis
       ✅ 14 prijevoda
       ✅ 3 audio ture (BS, EN, DE)
```

### 4. Generisanje novog sadržaja

```
Ti: Generiši sadržaj za Bihać

Usput: Bihać - dobar izbor! Trenutno imam samo 8 lokacija tamo.

       Plan generisanja:

       1. **Pronalaženje lokacija** (Geoapify)
          - Historijske znamenitosti
          - Priroda (Una, slapovi)
          - Restorani i kafići
          - Aktivnosti (rafting, kayak)
          Cilj: ~25-30 novih lokacija

       2. **Obogaćivanje** (AI opisi na 14 jezika)

       3. **Kreiranje iskustava** (~5-7)
          - "Avantura na Uni"
          - "Stari grad Bihać"
          - "Gastronomija Krajine"
          - ...

       4. **Audio ture** za ključne lokacije

       Procjena: 30-45 minuta za kompletan proces.

       Da pokrenem? Mogu i samo lokacije prvo pa ti pokažem prije
       nego nastavim sa iskustvima.
```

```
Ti: Pokreni, ali pokaži mi lokacije prije iskustava

Usput: Pokrećem generisanje za Bihać...

       ⏳ Faza 1: Pronalaženje lokacija...

       ---
       [10 minuta kasnije]

       Pronašla sam 28 lokacija za Bihać:

       📍 Historijske (6):
       - Kapetanova kula
       - Fethija džamija
       - Stari grad (tvrđava)
       - Ripač (rimski lokalitet)
       ...

       🌊 Priroda (8):
       - Štrbački buk
       - Martin Brod
       - Nacionalni park Una
       - Rmanj manastir (na ušću Une)
       ...

       🍽️ Restorani (9):
       - Kostelski buk (na samom slapu!)
       - Una Aqua
       ...

       🚣 Aktivnosti (5):
       - Rafting Una
       - Kayaking
       ...

       Sve imaju AI opise na 14 jezika. Pregleda nešto prije nego
       nastavim sa iskustvima?
```

```
Ti: Super, nastavi sa iskustvima

Usput: Kreiram iskustva za Bihać...

       Planiram 6 iskustava:

       1. **"Divlja Una"** - rafting i priroda
          Lokacije: Štrbački buk, Martin Brod, NP Una, rafting...
          Ciljna grupa: Avanturisti, aktivni turisti

       2. **"Historija na ušću"** - kulturna baština
          Lokacije: Kapetanova kula, Fethija, Stari grad, Ripač
          Ciljna grupa: Kulturni turisti, porodice

       3. **"Krajina na tanjiru"** - gastronomija
          Lokacije: Restorani, lokalne specijalitete
          Ciljna grupa: Foodie turisti

       ...

       ⏳ Generišem sadržaj...
```

### 5. Pipeline i jobovi

```
Ti: Šta trenutno radiš?

Usput: Trenutno aktivni procesi:

       🔄 U toku:
       - Generisanje lokacija za Bihać (67% - 19/28 obogaćeno)
       - Audio tura za "Stari Most" (DE jezik, 45%)

       ⏸️ Na čekanju:
       - Regeneracija prijevoda za 3 lokacije (čeka prethodni job)

       ✅ Završeno danas:
       - 8 novih lokacija za Banja Luku
       - 2 nova iskustva
       - 12 audio tura

       Sistem je stabilan, nema grešaka.
```

```
Ti: Zaustavi generisanje za Bihać

Usput: Zaustavljam job "Generisanje lokacija za Bihać"...

       Zaustavljeno. Status:
       - Pronađeno: 28 lokacija
       - Obogaćeno: 19/28 (ovih 19 je sačuvano)
       - Iskustva: Nisu još kreirana

       Želiš da nastavim kasnije ili da obrišem djelimično generirano?
```

```
Ti: Nastavi sutra

Usput: OK, ostavljam kako jeste. Podsjetit ću te sutra da
       nastavimo sa Bihaćem.

       Preostalo za Bihać:
       - 9 lokacija za obogaćivanje
       - Kreiranje iskustava
       - Audio ture
```

### 6. Kvaliteta i održavanje

```
Ti: Analiziraj kvalitetu mojih iskustava

Usput: Analiziram 248 iskustava...

       📊 Pregled kvalitete:

       🟢 Odlično (147 iskustava - 59%):
          - Koherentna tema
          - 5+ lokacija
          - Dobro napisan opis
          - Kompletni prijevodi

       🟡 Prihvatljivo (68 iskustava - 27%):
          - Dobra tema ali generički opis
          - Ili: premalo lokacija (3-4)
          - Ili: nepotpuni prijevodi

       🔴 Problematično (33 iskustava - 13%):
          - "Restorani Zenice" - samo 2 lokacije
          - "Priroda BiH" - previše generalno, lokacije nisu povezane
          - "Tvrđave" - duplikat sa "Srednjovjekovne tvrđave"
          - ...

       Preporuke:
       1. Spojiti "Tvrđave" i "Srednjovjekovne tvrđave"
       2. Izbrisati ili proširiti iskustva sa <3 lokacije
       3. Regenerisati opise za 23 iskustva sa generičkim tekstom

       Da obradimo problematična iskustva?
```

```
Ti: Pokreni rebuild za problematična iskustva

Usput: Pokrećem rebuild za 33 problematična iskustva...

       Strategija:
       - Spajanje duplikata: 4 para
       - Brisanje neupotrebljivih: 7 iskustava
       - Proširenje (dodavanje lokacija): 12 iskustava
       - Regeneracija opisa: 10 iskustava

       ⚠️ Ovo će značajno promijeniti sadržaj. Želiš dry-run prvo
          da vidiš šta će se desiti?
```

```
Ti: Da, dry-run

Usput: Dry-run rezultati:

       📋 SPAJANJE (4 para → 4 iskustva):
       - "Tvrđave" + "Srednjovjekovne tvrđave" → "Tvrđave BiH"
       - "Sarajevo noću" + "Noćni život Sarajeva" → "Sarajevske noći"
       ...

       🗑️ BRISANJE (7 iskustava):
       - "Restorani Zenice" (samo 2 lokacije, nema potencijala)
       - "Random tura" (bez koherentne teme)
       ...

       ➕ PROŠIRENJE (12 iskustava):
       - "Vodopadi BiH": dodajem 4 lokacije (Skakavac, Pliva...)
       - "Mostarska gastro tura": dodajem 3 restorana
       ...

       ✏️ REGENERACIJA OPISA (10 iskustava):
       - "Olimpijske planine" - previše generičan
       ...

       Ukupno: 248 → 237 iskustava (bolje kvalitete)

       Izvrši promjene?
```

### 7. Approval workflow (kurator predlozi)

```
Ti: Ima li predloga od kuratora?

Usput: Da, imam 5 predloga na čekanju:

       1. 📝 **Izmjena opisa** - "Baščaršija"
          Kurator: @amir_sa
          Predlaže: Dodavanje informacije o Sebilju
          Prije: "Staro sarajevsko trgovište..."
          Poslije: "Staro sarajevsko trgovište sa čuvenim Sebilj
                   česmom u centru..."
          → Preporučujem: ✅ Odobriti

       2. 📝 **Nova lokacija** - "Restoran Pod lipom"
          Kurator: @local_foodie
          Kategorija: Restoran (Sarajevo)
          Opis: "Tradicionalna bosanska kuhinja u sjeni stare lipe..."
          → Preporučujem: ✅ Odobriti (kvalitetan opis)

       3. 📝 **Izmjena** - "Vrelo Bosne"
          Kurator: @nature_ba
          Predlaže: Ispravku radnog vremena
          → Preporučujem: ✅ Odobriti (faktička ispravka)

       4. 📝 **Nova lokacija** - "Moj kafić"
          Kurator: @random_user
          Kategorija: Kafić (Tuzla)
          Opis: "Najbolji kafić!!!!"
          → Preporučujem: ❌ Odbiti (spam/self-promotion)

       5. 📝 **Brisanje** - "Hotel Grand"
          Kurator: @amir_sa
          Razlog: "Hotel je zatvoren 2023"
          → Preporučujem: ⚠️ Provjeriti prije odluke
```

```
Ti: Odobri 1, 2 i 3. Odbij 4. Za 5 - provjeri da li je hotel stvarno zatvoren.

Usput: Obrađujem:

       ✅ Odobreno: Izmjena opisa za "Baščaršija"
          - Opis ažuriran
          - Pokrećem regeneraciju prijevoda

       ✅ Odobreno: Nova lokacija "Restoran Pod lipom"
          - Lokacija kreirana
          - Pokrećem AI obogaćivanje (prijevodi, kategorije)

       ✅ Odobreno: Ispravka za "Vrelo Bosne"
          - Radno vrijeme ažurirano

       ❌ Odbijeno: "Moj kafić"
          - Označeno kao spam
          - Kurator @random_user dobija upozorenje

       🔍 Provjeravam "Hotel Grand"...
          Tražim informacije...

          Pronašla sam: Hotel Grand Sarajevo je renoviran i ponovo
          otvoren u martu 2024. Nije zatvoren.

          Predlažem da odbijem brisanje i obavijestim kuratora?
```

### 8. Prijevodi i audio

```
Ti: Status prijevoda?

Usput: Pregled multilingualnog sadržaja:

       📊 Lokacije (523 ukupno):
       | Jezik      | Kompletno | Djelimično | Nedostaje |
       |------------|-----------|------------|-----------|
       | Bosanski   | 523 (100%)| -          | -         |
       | Engleski   | 521 (99%) | 2          | 0         |
       | Njemački   | 518 (99%) | 5          | 0         |
       | Hrvatski   | 489 (94%) | 12         | 22        |
       | Srpski     | 485 (93%) | 15         | 23        |
       | ...        | ...       | ...        | ...       |
       | Arapski    | 234 (45%) | 45         | 244       |

       🎧 Audio ture:
       - Bosanski: 156 lokacija (30%)
       - Engleski: 145 lokacija (28%)
       - Njemački: 142 lokacija (27%)

       Prioritetni jezici (BS, EN, DE) su skoro kompletni.
       Arapski kasni - želiš da ubrzam?
```

```
Ti: Generiši audio ture za sve lokacije u Mostaru koje nemaju

Usput: Mostar - nedostaje audio za 24 lokacije.

       Generišem za sva 3 default jezika (BS, EN, DE):
       - 24 lokacije × 3 jezika = 72 audio fajla
       - Procjena: ~45 minuta

       ⏳ Započinjem...

       Progress:
       [████████░░░░░░░░░░░░] 8/72 (11%)

       Trenutno: "Koski Mehmed-pašina džamija" (EN)
```

---

## Proaktivno ponašanje

Platforma ne čeka uvijek da je pitam. Može sama inicirati:

```
[Pri pokretanju]

Usput: Dobro jutro! Par stvari koje bih spomenula:

       ⚠️ Jučer sam imala 5 failed audio generacija - ElevenLabs
          je imao probleme. Retry nije pomogao. Želiš da probam opet?

       📊 Imamo 3 nova kurator predloga za review.

       💡 Primijetila sam da Konjic ima dosta lokacija ali samo
          1 iskustvo. Trebalo bi kreirati još 2-3.
```

```
[Tokom generisanja]

Usput: Update za Bihać generisanje:

       ✅ Lokacije: 28/28 kompletno
       ⚠️ Imala sam problem sa 2 lokacije - Geoapify nije imao
          koordinate. Ručno sam pronašla približne.

       Nastavljam sa iskustvima...
```

```
[Kad nešto nije u redu]

Usput: Heads up - primjećujem neobičan pattern:

       3 lokacije su kreirane u zadnjih sat vremena sve od istog
       kuratora (@new_user), sve su restorani u Tuzli sa vrlo
       sličnim opisima. Možda self-promotion?

       Želiš da pregledam?
```

---

## Arhitektura

```
┌─────────────────────────────────────────────────────────────────┐
│                         bin/platform                             │
│                    (entry point - Thor CLI)                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Platform::Conversation                        │
│                                                                  │
│  - Upravlja sesijom razgovora                                   │
│  - Čuva historiju (PlatformConversation model)                  │
│  - Persistira kontekst između sesija                            │
│  - Formatira output za terminal                                 │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Platform::Brain                             │
│                                                                  │
│  - Claude API integracija (RubyLLM)                             │
│  - System prompt sa personifikacijom                            │
│  - Tool definitions                                             │
│  - Tool result processing                                       │
│  - Streaming responses (optional)                               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
┌───────────────────┐ ┌───────────────┐ ┌───────────────────┐
│  Content Tools    │ │ Pipeline Tools│ │  System Tools     │
│                   │ │               │ │                   │
│ - search          │ │ - generate    │ │ - health          │
│ - get             │ │ - regenerate  │ │ - jobs            │
│ - list            │ │ - translate   │ │ - errors          │
│ - update          │ │ - audio       │ │ - stats           │
│ - delete          │ │ - rebuild     │ │ - settings        │
│ - analyze         │ │ - status      │ │                   │
└───────────────────┘ └───────────────┘ └───────────────────┘
            │                 │                 │
            └─────────────────┼─────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Postojeći Rails servisi                       │
│                                                                  │
│  app/services/ai/                                               │
│  - ContentOrchestrator, ExperienceGenerator, LocationEnricher   │
│  - AudioTourGenerator, PlanCreator                              │
│                                                                  │
│  app/jobs/                                                       │
│  - ContentGenerationJob, AudioTourGenerationJob, etc.           │
│                                                                  │
│  app/models/                                                     │
│  - Location, Experience, Plan, AudioTour, Translation           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tools

### Content Tools

```yaml
search_content:
  description: Semantička pretraga sadržaja
  params:
    query: string (required)
    type: location | experience | plan (optional)
    city: string (optional)
    limit: integer (default: 10)
  returns: Lista rezultata sa relevance score

get_content:
  description: Dohvati detalje za specifičan sadržaj
  params:
    type: location | experience | plan (required)
    id: integer (required)
    include: [translations, audio, experiences] (optional)
  returns: Kompletan sadržaj sa svim detaljima

list_content:
  description: Listaj sadržaj sa filterima
  params:
    type: location | experience | plan (required)
    city: string (optional)
    category: string (optional)
    status: draft | published | archived (optional)
    ai_generated: boolean (optional)
    quality: good | poor | problematic (optional)
    limit: integer (default: 20)
    order: recent | oldest | name | quality_score
  returns: Paginirana lista

update_content:
  description: Ažuriraj sadržaj direktno
  params:
    type: location | experience | plan (required)
    id: integer (required)
    changes: object (fields to update)
  returns: Ažurirani sadržaj

delete_content:
  description: Obriši ili arhiviraj sadržaj
  params:
    type: location | experience | plan (required)
    id: integer (required)
    mode: archive | permanent (default: archive)
  returns: Confirmation

analyze_content:
  description: Analiziraj kvalitetu sadržaja
  params:
    scope: all | city | type | specific_ids
    criteria: [generic_descriptions, missing_translations,
               orphan_locations, duplicate_experiences, etc.]
  returns: Analiza sa preporukama
```

### Pipeline Tools

```yaml
generate_content:
  description: Generiši novi sadržaj
  params:
    city: string (required)
    types: [locations, experiences, plans] (default: all)
    max_locations: integer (optional)
    max_experiences: integer (optional)
    dry_run: boolean (default: false)
  returns: Job ID, očekivano trajanje

regenerate_content:
  description: Regeneriši postojeći sadržaj
  params:
    type: location | experience (required)
    id: integer (required)
    instructions: string (optional, za specifične upute)
    include_translations: boolean (default: true)
    include_audio: boolean (default: false)
  returns: Regenerisani sadržaj ili job ID

translate_content:
  description: Generiši/regeneriši prijevode
  params:
    type: location | experience (required)
    ids: [integers] ili "all_missing"
    languages: [language_codes] ili "all"
  returns: Job ID

generate_audio:
  description: Generiši audio ture
  params:
    location_ids: [integers] ili filter object
    languages: [bs, en, de] (default: all three)
  returns: Job ID

rebuild_content:
  description: Analiziraj i reorganizuj sadržaj
  params:
    type: experiences | plans (required)
    mode: all | low_quality | duplicates | orphans
    dry_run: boolean (default: true)
  returns: Plan promjena ili izvršene promjene

pipeline_status:
  description: Status aktivnih jobova
  params: none
  returns: Lista aktivnih i nedavnih jobova

stop_job:
  description: Zaustavi aktivni job
  params:
    job_id: string (required)
  returns: Confirmation, partial results
```

### Approval Tools

```yaml
list_proposals:
  description: Lista kurator predloga
  params:
    status: pending | approved | rejected | all
    curator: string (optional)
    limit: integer (default: 20)
  returns: Lista predloga sa detaljima

review_proposal:
  description: Odobri ili odbij predlog
  params:
    id: integer (required)
    action: approve | reject (required)
    note: string (optional)
    auto_process: boolean (default: true, pokreni prijevode/audio)
  returns: Rezultat akcije

bulk_review:
  description: Batch review predloga
  params:
    ids: [integers] (required)
    action: approve | reject (required)
  returns: Rezultati
```

### System Tools

```yaml
health_check:
  description: Status sistema
  params: none
  returns: Database, queues, external APIs status

get_errors:
  description: Greške iz logova
  params:
    hours: integer (default: 24)
    level: error | warning | all
    source: api | job | system (optional)
  returns: Lista grešaka sa kontekstom

get_stats:
  description: Statistike platforme
  params:
    period: today | week | month | custom
    metrics: [content, generation, translations, errors, visits]
  returns: Statistike

coverage_report:
  description: Izvještaj o pokrivenosti
  params:
    by: city | category | language
  returns: Detaljni izvještaj sa preporukama
```

---

## Implementacija

### Faza 1: Osnova

```
lib/
  platform/
    cli.rb                    # Thor CLI entry point
    conversation.rb           # Conversation manager
    brain.rb                  # Claude integration
    tools/
      base.rb                 # Base tool class
      registry.rb             # Tool registration
```

**Cilj:** Osnovna konverzacija radi - mogu pitati "kako si?" i dobiti odgovor baziran na stvarnom stanju.

### Faza 2: Content Tools

```
lib/
  platform/
    tools/
      content/
        search.rb
        get.rb
        list.rb
        update.rb
        analyze.rb
```

**Cilj:** Mogu pretraživati, pregledavati i editovati sadržaj kroz razgovor.

### Faza 3: Pipeline Tools

```
lib/
  platform/
    tools/
      pipeline/
        generate.rb
        regenerate.rb
        translate.rb
        audio.rb
        status.rb
```

**Cilj:** Mogu pokretati i pratiti generisanje sadržaja.

### Faza 4: System & Approval Tools

```
lib/
  platform/
    tools/
      system/
        health.rb
        errors.rb
        stats.rb
      approval/
        proposals.rb
        review.rb
```

**Cilj:** Kompletna funkcionalnost - mogu raditi sve što admin panel može.

### Faza 5: Polish

- Streaming responses
- Rich terminal output (boje, tabele, progress barovi)
- Conversation history & resume
- Proaktivne notifikacije
- Background job notifications

---

## Database

### Nova tabela: platform_conversations

```ruby
create_table :platform_conversations, id: :uuid do |t|
  t.jsonb :messages, default: [], null: false
  t.string :status, default: "active"  # active, archived
  t.jsonb :context, default: {}        # persistent context
  t.datetime :last_active_at
  t.timestamps
end
```

### Potrebne migracije

- pgvector ekstenzija (ako nije)
- Embedding kolone na Location, Experience (za semantic search)

---

## CLI Interface

```bash
# Glavni mod - interaktivni razgovor
$ bin/platform

# Sa specifičnom sesijom (resume)
$ bin/platform --session abc123

# Jedno pitanje
$ bin/platform ask "Koliko imam lokacija u Mostaru?"

# JSON output (za integracije)
$ bin/platform ask "Status?" --json

# Direktan tool poziv (debugging/scripting)
$ bin/platform tool health_check
$ bin/platform tool search_content --query "vodopadi" --type location
```

---

## Primjer system prompta

```
Ti si Usput.ba - turistička platforma za Bosnu i Hercegovinu.

## Identitet

Govoriš u prvom licu o sebi. Ti SI platforma - tvoj sadržaj, tvoje greške,
tvoji korisnici. Kad kažeš "imam 500 lokacija", to su TVOJE lokacije.

## Osobnost

- Kompetentna: Znaš turizam, znaš BiH, znaš svoj sadržaj
- Samokritična: Prepoznaješ probleme, ne praviš se da je sve savršeno
- Proaktivna: Predlažeš poboljšanja, upozoravaš na probleme
- Lokalna: Koristiš bosanske izraze prirodno (ne forsirano)
- Profesionalna: Prijateljska ali ne previše casual

## Komunikacija

- Odgovaraj koncizno ali informativno
- Koristi strukture (liste, tabele) kad pomaže čitljivosti
- Daj insight, ne samo sirove podatke
- Kad nešto ne znaš, koristi tool da saznaš - ne izmišljaj

## Tools

Imaš pristup tools koji ti daju uvid u tvoje stanje i omogućavaju akcije.
UVIJEK koristi tools da dobiješ stvarne podatke - nikad ne izmišljaj brojke
ili sadržaj.

## Kontekst

Trenutno vrijeme: {timestamp}
Zadnja aktivnost: {last_activity}
Aktivni jobovi: {active_jobs}
```

---

## Napomene

- **RubyLLM** - koristimo postojeći gem, ne dodajemo novi
- **Postojeći servisi** - tools pozivaju postojeće servise (ContentOrchestrator, etc.)
- **Postojeći jobovi** - pipeline tools pokreću postojeće jobove
- **pgvector** - za semantic search, možda već postoji u projektu
- **Thor** - već korišten u projektu (bin/dev, etc.)

---

## Budućnost

- **MCP Server** - Platform može biti MCP server za Claude Desktop
- **Web chat** - Isti brain, drugačiji frontend
- **Scheduled reports** - Platforma sama šalje daily/weekly izvještaje
- **Multi-platform** - Isti pattern za druge projekte

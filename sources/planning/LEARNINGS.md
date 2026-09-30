# Learnings - Ekstrahirani Patterns

Dokumentacija korisnih patterns ekstrahiranih iz maintenance skripti i development sesija.

*Zadnje ažuriranje: 2026-02-02*

---

## 1. Translation Pattern

Standardni način za dodavanje/ažuriranje prijevoda lokacija:

```ruby
# BS opis
t_bs = Translation.find_or_initialize_by(
  translatable_type: "Location",
  translatable_id: location.id,
  locale: "bs",
  field_name: "description"
)
t_bs.value = "Opis na bosanskom..."
t_bs.save!

# EN opis
t_en = Translation.find_or_initialize_by(
  translatable_type: "Location",
  translatable_id: location.id,
  locale: "en",
  field_name: "description"
)
t_en.value = "Description in English..."
t_en.save!
```

**Važno:**
- Koristi `find_or_initialize_by` za upsert pattern
- `field_name` je uvijek `"description"` za opise
- Locale-i: `bs`, `en`, `de`, `hr`, `sr`, itd.

---

## 2. Experience Type Association Pattern

Dodavanje experience types lokaciji:

```ruby
types = ["culture", "history", "nature"]

types.each do |type_name|
  et = ExperienceType.find_by(name: type_name)
  if et
    let = LocationExperienceType.find_or_initialize_by(
      location_id: location.id,
      experience_type_id: et.id
    )
    let.save!
  end
end
```

**Dostupni tipovi:**
- `adventure`, `culture`, `food`, `nature`, `relaxation`
- `urban`, `history`, `religious`, `family`, `romantic`

---

## 3. AI Prompt za Generisanje Opisa

Optimalan prompt za RubyLLM generisanje opisa:

```ruby
prompt = <<~PROMPT
  Ti si turistički vodič za Bosnu i Hercegovinu.
  Napiši zanimljiv i informativan opis za sljedeću lokaciju:

  Naziv: #{loc.name}
  Grad: #{loc.city}
  Tagovi: #{loc.tags.join(", ")}

  Opis treba biti:
  - Na bosanskom jeziku (ijekavica!)
  - Minimum 150 karaktera
  - Informativan i privlačan za turiste
  - Specifičan za ovu lokaciju (ne generički)
  - Bez klišeja poput "raj na zemlji" ili "biserne lokacije"

  Vrati SAMO opis, bez naslova ili dodatnih objašnjenja.
PROMPT

chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
response = chat.ask(prompt)
description = response.content.strip
```

---

## 4. Complete Location Enrichment Workflow

Kompletan flow za obogaćivanje lokacije:

```ruby
def enrich_location(location)
  # 1. Generiši BS opis
  bs_desc = generate_description(location, locale: "bs")
  save_translation(location, "bs", bs_desc)

  # 2. Generiši EN opis
  en_desc = translate_to_english(bs_desc)
  save_translation(location, "en", en_desc)

  # 3. Dodaj experience types
  types = determine_experience_types(location, bs_desc)
  add_experience_types(location, types)

  # 4. Ažuriraj tagove
  location.tags = generate_tags(location)
  location.save!
end
```

---

## 5. Quality Content Examples

### Dobri primjeri opisa (iz Trebinje batch-a)

**Muzej:**
> "Muzej Hercegovine u Trebinju čuva bogatu baštinu ovog historijskog grada. Osnovan sredinom 20. stoljeća, muzej prezentira arheološke nalaze od prahistorije do srednjeg vijeka, etnografsku zbirku sa tradicionalnim nošnjama i predmetima svakodnevnog života, te umjetničku kolekciju djela lokalnih majstora."

**Vinarija:**
> "Vinarija Vukoje jedna je od najpoznatijih vinarija u Hercegovini, smještena u predivnom krajoliku vinograda nedaleko od Trebinja. Porodica Vukoje njeguje tradiciju vinogradarstva već generacijama, proizvodeći vrhunska vina od autohtonih sorti grožđa kao što su vranac i žilavka."

### Karakteristike kvalitetnog opisa:
- 150-300 karaktera
- Specifični detalji (godine, nazivi, lokacije)
- Emocionalan ali informativan ton
- Spominje šta posjetilac može vidjeti/uraditi
- Bez generičkih fraza

---

## 6. Sensitive Content Guidelines

### Lokacije koje zahtijevaju posebnu pažnju:

| Tip | Pristup |
|-----|---------|
| Ratni memorijali | Respectful, factual, fokus na sjećanje |
| Vjerski objekti | Neutralan ton, jednako tretirati sve religije |
| Partizanska groblja | Historijski kontekst, arhitektura |
| Genocid memorijali | **REFUSE AI generation** - human review |

**Primjer - Partizansko groblje Konjic:**
> "Partizansko groblje u Konjicu predstavlja monumentalni spomenik posvećen borcima Narodnooslobodilačke borbe iz Drugog svjetskog rata. Dizajnirano od strane poznatog arhitekte Bogdana Bogdanovića, ovo groblje je dio serije njegovih impresivnih spomenika širom bivše Jugoslavije."

---

## 7. Tags Pattern

Korisni tagovi po kategorijama:

```ruby
# Kulturne lokacije
["museum", "gallery", "history", "architecture", "art"]

# Religijske lokacije
["mosque", "church", "monastery", "religious", "spiritual"]

# Prirodne lokacije
["nature", "river", "mountain", "waterfall", "park"]

# Gastronomske lokacije
["restaurant", "winery", "food", "traditional", "local-cuisine"]

# Memorijalne lokacije
["memorial", "history", "monument", "remembrance"]
```

---

## 8. Experience Location Association Pattern

Dodavanje lokacije iskustvu:

```ruby
experience = Experience.find(263)
location = Location.find(744)

experience.experience_locations.find_or_create_by!(location: location) do |el|
  el.position = experience.experience_locations.count + 1
end
```

---

## 9. Batch Operations Pattern

Pronalaženje iskustava sa nedovoljno lokacija i automatsko dodavanje:

```ruby
Experience.joins(:experience_locations)
  .group('experiences.id')
  .having('COUNT(experience_locations.id) = 2')
  .each do |exp|
    # Get cities of existing locations
    existing_loc_ids = exp.experience_locations.pluck(:location_id)
    cities = Location.where(id: existing_loc_ids).pluck(:city).uniq

    next if cities.size > 1 # Skip multi-city experiences

    city = cities.first

    # Find another location in the same city with description
    new_loc = Location.where(city: city)
      .where.not(id: existing_loc_ids)
      .where("LENGTH(description) >= 100")
      .first

    next unless new_loc

    # Add the new location
    exp.experience_locations.create!(
      location: new_loc,
      position: exp.experience_locations.count + 1
    )
  end
```

---

## 10. Model Alternativa za AI Generation

Skripte koriste različite modele:

| Model | Provider | Use Case |
|-------|----------|----------|
| `claude-sonnet-4-20250514` | Anthropic | Quality descriptions |
| `gpt-4o-mini` | OpenAI | Quick batch operations |

**RubyLLM konfiguracija:**
```ruby
# Anthropic
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
end
chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")

# OpenAI
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
end
chat = RubyLLM.chat(model: "gpt-4o-mini")
```

---

## Reference

- Originalne skripte: `tmp/*.rb` (obrisane 2026-02-02)
- Platform DSL: `lib/platform/dsl/`
- Translation model: `app/models/translation.rb`
- ExperienceType: `app/models/experience_type.rb`

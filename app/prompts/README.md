# AI Prompts

Svi AI promptovi za Usput.ba platformu.

## Struktura

```
app/prompts/
├── README.md
├── audio_tour_generator/
│   └── script.md.erb              # Audio tour naracija
├── experience_location_syncer/
│   └── extract_locations.md.erb   # Ekstrakcija lokacija iz opisa
├── experience_type_classifier/
│   ├── system.md.erb              # System prompt za klasifikator
│   └── classify.md.erb            # Klasifikacija pojedinačne lokacije
└── location_enricher/
    ├── metadata.md.erb            # Metadata (tags, tips, experience types)
    ├── descriptions.md.erb        # Opisi na više jezika
    └── historical_context.md.erb  # Historijski kontekst
```

## Korištenje

```ruby
# U Rails servisu
include PromptHelper

# Prompt sa varijablama (ERB)
prompt = load_prompt("experience_type_classifier/system.md.erb",
  available_types: "nature, culture, adventure")

prompt = load_prompt("location_enricher/metadata.md.erb",
  name: "Stari Most",
  city: "Mostar",
  cultural_context: Ai::BihContext::BIH_CULTURAL_CONTEXT,
  # ...
)
```

## Servisi koji koriste promptove

| Servis | Prompt fajlovi |
|--------|----------------|
| `Ai::ExperienceTypeClassifier` | `experience_type_classifier/system.md.erb`, `classify.md.erb` |
| `Ai::LocationEnricher` | `location_enricher/metadata.md.erb`, `descriptions.md.erb`, `historical_context.md.erb` |
| `Ai::AudioTourGenerator` | `audio_tour_generator/script.md.erb` |
| `Ai::ExperienceLocationSyncer` | `experience_location_syncer/extract_locations.md.erb` |

## Pravila

1. **NIKAD** pisati promptove direktno u servisima
2. Svi fajlovi koriste `.md.erb` ekstenziju (ERB template)
3. Jedan folder po servisu
4. Varijable se proslijeđuju kroz `load_prompt(path, **vars)`

## Testiranje

```bash
bin/rails test test/helpers/prompt_helper_test.rb
```

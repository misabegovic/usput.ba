# frozen_string_literal: true

# I18n fallback configuration
# When a translation is missing, fallback to these locales in order

Rails.application.config.after_initialize do
  I18n.fallbacks = {
    hr: [ :hr, :bs, :sr, :en ],      # Croatian -> Bosnian -> Serbian -> English
    bs: [ :bs, :hr, :sr, :en ],      # Bosnian -> Croatian -> Serbian -> English
    sr: [ :sr, :hr, :bs, :en ],      # Serbian -> Croatian -> Bosnian -> English
    sl: [ :sl, :hr, :en ],           # Slovenian -> Croatian -> English
    de: [ :de, :en ],                # German -> English
    es: [ :es, :pt, :en ],           # Spanish -> Portuguese -> English
    pt: [ :pt, :es, :en ],           # Portuguese -> Spanish -> English
    fr: [ :fr, :en ],                # French -> English
    it: [ :it, :es, :en ],           # Italian -> Spanish -> English
    nl: [ :nl, :de, :en ],           # Dutch -> German -> English
    pl: [ :pl, :cs, :sk, :en ],      # Polish -> Czech -> Slovak -> English
    cs: [ :cs, :sk, :pl, :en ],      # Czech -> Slovak -> Polish -> English
    sk: [ :sk, :cs, :pl, :en ],      # Slovak -> Czech -> Polish -> English
    tr: [ :tr, :en ],                # Turkish -> English
    ar: [ :ar, :en ],                # Arabic -> English
    en: [ :en ]                      # English (no fallback needed)
  }
end

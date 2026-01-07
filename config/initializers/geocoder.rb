# Geocoder konfiguracija
# https://github.com/alexreisner/geocoder

Geocoder.configure(
  # Osnovne postavke za geokodiranje
  timeout: 5,                     # timeout za geokodiranje u sekundama
  units: :km,                     # koristi kilometre za udaljenosti

  # Koristi lokalne izračune za udaljenosti (bez eksternog API-ja)
  distances: :spherical,          # sferični izračun udaljenosti (Haversine formula)

  # Postavke za lookup (koristi Nominatim kao besplatnu opciju)
  # Možeš promijeniti na Google, Bing ili drugi provider ako imaš API ključ
  lookup: :nominatim,
  ip_lookup: :ipinfo_io,

  # Nominatim postavke (OpenStreetMap)
  nominatim: {
    host: "nominatim.openstreetmap.org",
    use_https: true
  },

  # Keširanje rezultata (smanjuje API pozive)
  cache: Rails.cache,
  cache_options: {
    expiration: 1.day
  }
)

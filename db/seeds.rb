# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed Locales
puts "Seeding locales..."

locales_data = [
  { code: "en", name: "English", native_name: "English", flag_emoji: "🇬🇧", position: 1, ai_supported: true },
  { code: "bs", name: "Bosnian", native_name: "Bosanski", flag_emoji: "🇧🇦", position: 2, ai_supported: true },
  { code: "hr", name: "Croatian", native_name: "Hrvatski", flag_emoji: "🇭🇷", position: 3, ai_supported: true },
  { code: "de", name: "German", native_name: "Deutsch", flag_emoji: "🇩🇪", position: 4, ai_supported: true },
  { code: "es", name: "Spanish", native_name: "Español", flag_emoji: "🇪🇸", position: 5, ai_supported: true },
  { code: "fr", name: "French", native_name: "Français", flag_emoji: "🇫🇷", position: 6, ai_supported: true },
  { code: "it", name: "Italian", native_name: "Italiano", flag_emoji: "🇮🇹", position: 7, ai_supported: true },
  { code: "pt", name: "Portuguese", native_name: "Português", flag_emoji: "🇵🇹", position: 8, ai_supported: true },
  { code: "nl", name: "Dutch", native_name: "Nederlands", flag_emoji: "🇳🇱", position: 9, ai_supported: true },
  { code: "pl", name: "Polish", native_name: "Polski", flag_emoji: "🇵🇱", position: 10, ai_supported: true },
  { code: "cs", name: "Czech", native_name: "Čeština", flag_emoji: "🇨🇿", position: 11, ai_supported: true },
  { code: "sk", name: "Slovak", native_name: "Slovenčina", flag_emoji: "🇸🇰", position: 12, ai_supported: true },
  { code: "sl", name: "Slovenian", native_name: "Slovenščina", flag_emoji: "🇸🇮", position: 13, ai_supported: true },
  { code: "sr", name: "Serbian", native_name: "Српски", flag_emoji: "🇷🇸", position: 14, ai_supported: true },
  { code: "tr", name: "Turkish", native_name: "Türkçe", flag_emoji: "🇹🇷", position: 15, ai_supported: true },
  { code: "ar", name: "Arabic", native_name: "العربية", flag_emoji: "🇸🇦", position: 16, ai_supported: true }
]

locales_data.each do |locale_data|
  Locale.find_or_create_by!(code: locale_data[:code]) do |locale|
    locale.name = locale_data[:name]
    locale.native_name = locale_data[:native_name]
    locale.flag_emoji = locale_data[:flag_emoji]
    locale.position = locale_data[:position]
    locale.ai_supported = locale_data[:ai_supported]
    locale.active = true
  end
end

puts "Created #{Locale.count} locales"

# Seed Experience Types
puts "Seeding experience types..."

experience_types_data = [
  { key: "culture", name: "Culture", icon: "🎭", color: "#8B5CF6", position: 1 },
  { key: "history", name: "History", icon: "🏛️", color: "#6366F1", position: 2 },
  { key: "sport", name: "Sport & Adventure", icon: "⛷️", color: "#10B981", position: 3 },
  { key: "food", name: "Food & Drink", icon: "🍽️", color: "#F59E0B", position: 4 },
  { key: "nature", name: "Nature", icon: "🌲", color: "#059669", position: 5 },
  { key: "woods", name: "Woods & Forests", icon: "🌳", color: "#065F46", position: 6 },
  { key: "mountains", name: "Mountains", icon: "⛰️", color: "#7C3AED", position: 7 },
  { key: "vegan", name: "Vegan", icon: "🥗", color: "#84CC16", position: 8 },
  { key: "vegetarian", name: "Vegetarian", icon: "🥕", color: "#22C55E", position: 9 },
  { key: "meat", name: "Meat & BBQ", icon: "🥩", color: "#DC2626", position: 10 },
  { key: "religious", name: "Religious & Spiritual", icon: "🕌", color: "#0EA5E9", position: 11 },
  { key: "art", name: "Art & Museums", icon: "🖼️", color: "#EC4899", position: 12 },
  { key: "nightlife", name: "Nightlife", icon: "🎶", color: "#A855F7", position: 13 },
  { key: "wellness", name: "Wellness & Spa", icon: "💆", color: "#14B8A6", position: 14 }
]

experience_types_data.each do |type_data|
  ExperienceType.find_or_create_by!(key: type_data[:key]) do |exp_type|
    exp_type.name = type_data[:name]
    exp_type.icon = type_data[:icon]
    exp_type.color = type_data[:color]
    exp_type.position = type_data[:position]
    exp_type.active = true
  end
end

puts "Created #{ExperienceType.count} experience types"

# Seed Experience Categories
puts "Seeding experience categories..."

experience_categories_data = [
  {
    key: "cultural_heritage",
    name: "Cultural Heritage",
    icon: "🏛️",
    default_duration: 180,
    position: 1,
    experience_types: %w[culture history]
  },
  {
    key: "culinary_journey",
    name: "Culinary Journey",
    icon: "🍽️",
    default_duration: 120,
    position: 2,
    experience_types: %w[food]
  },
  {
    key: "nature_adventure",
    name: "Nature Adventure",
    icon: "🌲",
    default_duration: 240,
    position: 3,
    experience_types: %w[nature sport]
  },
  {
    key: "local_life",
    name: "Local Life",
    icon: "🏘️",
    default_duration: 150,
    position: 4,
    experience_types: %w[culture food]
  },
  {
    key: "historical_walk",
    name: "Historical Walk",
    icon: "🚶",
    default_duration: 180,
    position: 5,
    experience_types: %w[history culture]
  },
  {
    key: "foodie_tour",
    name: "Foodie Tour",
    icon: "🥘",
    default_duration: 180,
    position: 6,
    experience_types: %w[food vegan vegetarian meat]
  },
  {
    key: "art_exploration",
    name: "Art Exploration",
    icon: "🖼️",
    default_duration: 120,
    position: 7,
    experience_types: %w[culture history art]
  },
  {
    key: "mountain_escape",
    name: "Mountain Escape",
    icon: "⛰️",
    default_duration: 300,
    position: 8,
    experience_types: %w[nature mountains sport]
  },
  {
    key: "forest_retreat",
    name: "Forest Retreat",
    icon: "🌳",
    default_duration: 240,
    position: 9,
    experience_types: %w[nature woods]
  },
  {
    key: "religious_heritage",
    name: "Religious Heritage",
    icon: "🕌",
    default_duration: 150,
    position: 10,
    experience_types: %w[religious history culture]
  },
  {
    key: "wellness_retreat",
    name: "Wellness Retreat",
    icon: "💆",
    default_duration: 180,
    position: 11,
    experience_types: %w[wellness nature]
  }
]

experience_categories_data.each do |category_data|
  category = ExperienceCategory.find_or_create_by!(key: category_data[:key]) do |cat|
    cat.name = category_data[:name]
    cat.icon = category_data[:icon]
    cat.default_duration = category_data[:default_duration]
    cat.position = category_data[:position]
    cat.active = true
  end

  # Add experience types to category
  category_data[:experience_types].each_with_index do |type_key, index|
    exp_type = ExperienceType.find_by(key: type_key)
    if exp_type
      category.add_experience_type(exp_type, position: index + 1)
    end
  end
end

puts "Created #{ExperienceCategory.count} experience categories"

# Seed Settings
puts "Seeding settings..."

settings_data = [
  # Geoapify settings
  { key: "geoapify.search_radius", value: "15000", type: "integer", category: "geoapify", description: "Default search radius in meters for Geoapify API" },
  { key: "geoapify.max_results", value: "50", type: "integer", category: "geoapify", description: "Maximum results to fetch from Geoapify" },
  { key: "geoapify.default_radius", value: "10000", type: "integer", category: "geoapify", description: "Default radius for nearby searches" },
  { key: "geoapify.default_max_results", value: "50", type: "integer", category: "geoapify", description: "Default max results for nearby searches" },
  { key: "geoapify.api_limit", value: "100", type: "integer", category: "geoapify", description: "API limit per request" },
  { key: "geoapify.batch_size", value: "5", type: "integer", category: "geoapify", description: "Batch size for category requests" },
  { key: "geoapify.text_search_max_results", value: "20", type: "integer", category: "geoapify", description: "Max results for text search" },
  { key: "geoapify.default_language", value: "en", type: "string", category: "geoapify", description: "Default language for API requests" },

  # AI settings
  { key: "ai.request_timeout", value: "120", type: "integer", category: "ai", description: "Request timeout for AI calls in seconds" },
  { key: "experience.min_locations", value: "1", type: "integer", category: "ai", description: "Minimum locations required for experience generation" },
  { key: "experience.max_locations", value: "5", type: "integer", category: "ai", description: "Maximum locations per experience" },
  { key: "location.max_tags", value: "10", type: "integer", category: "ai", description: "Maximum tags per location" },

  # Photo settings
  { key: "photo.download_timeout", value: "10", type: "integer", category: "photo", description: "Download timeout for photos in seconds" },
  { key: "photo.open_timeout", value: "5", type: "integer", category: "photo", description: "Connection timeout for photo downloads in seconds" },
  { key: "photo.max_size", value: "5242880", type: "integer", category: "photo", description: "Maximum photo size in bytes (5MB)" },

  # General settings
  { key: "generation.min_population", value: "50000", type: "integer", category: "general", description: "Minimum city population for batch generation" },
  { key: "generation.stagger_interval", value: "30", type: "integer", category: "general", description: "Seconds between generation jobs" }
]

settings_data.each do |setting_data|
  Setting.set(
    setting_data[:key],
    setting_data[:value],
    type: setting_data[:type],
    category: setting_data[:category],
    description: setting_data[:description]
  )
end

puts "Created #{Setting.count} settings"

# Seed Demo Users
puts "Seeding demo users..."

demo_users = [
  { username: "curator", password: "curator123", user_type: :curator },
  { username: "user", password: "user123", user_type: :basic }
]

demo_users.each do |user_data|
  User.find_or_create_by!(username: user_data[:username]) do |user|
    user.password = user_data[:password]
    user.user_type = user_data[:user_type]
  end
end

puts "Created #{User.count} users"

# Seed Locations for Sarajevo
puts "Seeding locations for Sarajevo..."

locations_data = [
  # Historical & Cultural
  {
    name: "Baščaršija",
    description: "The old bazaar and historical center of Sarajevo, dating back to the 15th century. A vibrant marketplace with traditional crafts, coffee houses, and Ottoman architecture.",
    historical_context: "Built by Isa-beg Isaković in 1462, Baščaršija has been the cultural and commercial heart of Sarajevo for over 500 years.",
    lat: 43.8598,
    lng: 18.4313,
    budget: :low,
    location_type: :place,
    tags: ["historic", "shopping", "culture", "ottoman", "old-town"],
    suitable_experiences: ["culture", "history", "food"],
    video_url: "https://www.youtube.com/watch?v=agHtkA2ttM0"
  },
  {
    name: "Sebilj Fountain",
    description: "An iconic wooden fountain in the heart of Baščaršija, a symbol of Sarajevo. Pigeons gather around this Ottoman-era fountain.",
    historical_context: "Originally built in 1753 and rebuilt in 1891, the Sebilj is one of the most photographed landmarks in Bosnia.",
    lat: 43.8598,
    lng: 18.4312,
    budget: :low,
    location_type: :place,
    tags: ["landmark", "historic", "photography", "ottoman"],
    suitable_experiences: ["culture", "history"]
  },
  {
    name: "Gazi Husrev-beg Mosque",
    description: "The largest historical mosque in Bosnia and Herzegovina, and one of the finest examples of Ottoman architecture in the Balkans.",
    historical_context: "Built in 1531 by Persian architect Acem Esir Ali, commissioned by Gazi Husrev-beg, the greatest Ottoman governor of Bosnia.",
    lat: 43.8597,
    lng: 18.4291,
    budget: :low,
    location_type: :place,
    tags: ["mosque", "historic", "architecture", "ottoman", "religious"],
    suitable_experiences: ["religious", "history", "culture", "art"],
    video_url: "https://www.youtube.com/watch?v=agHtkA2ttM0"
  },
  {
    name: "Latin Bridge",
    description: "Historic Ottoman bridge where Archduke Franz Ferdinand was assassinated in 1914, triggering World War I.",
    historical_context: "The assassination on June 28, 1914 set off a chain of events leading to World War I. The bridge dates from the Ottoman period.",
    lat: 43.8575,
    lng: 18.4287,
    budget: :low,
    location_type: :place,
    tags: ["historic", "bridge", "wwi", "landmark"],
    suitable_experiences: ["history", "culture"]
  },
  {
    name: "Sarajevo City Hall (Vijećnica)",
    description: "A stunning neo-Moorish building that served as the National Library. Destroyed during the siege and beautifully restored.",
    historical_context: "Built in 1896 during Austro-Hungarian rule. Tragically burned in 1992 during the siege, it was restored and reopened in 2014.",
    lat: 43.8582,
    lng: 18.4343,
    budget: :low,
    location_type: :place,
    tags: ["architecture", "historic", "library", "landmark", "austro-hungarian"],
    suitable_experiences: ["culture", "history", "art"],
    video_url: "https://www.youtube.com/watch?v=agHtkA2ttM0"
  },
  {
    name: "Sacred Heart Cathedral",
    description: "The largest cathedral in Bosnia and Herzegovina, a beautiful example of neo-Gothic architecture.",
    historical_context: "Completed in 1889 during Austro-Hungarian rule, designed by architect Josip Vancaš.",
    lat: 43.8577,
    lng: 18.4213,
    budget: :low,
    location_type: :place,
    tags: ["cathedral", "church", "architecture", "religious"],
    suitable_experiences: ["religious", "history", "culture", "art"]
  },
  {
    name: "Old Orthodox Church",
    description: "One of the oldest Orthodox churches in Sarajevo, housing a museum with valuable religious artifacts.",
    historical_context: "Built in the 16th century, this church contains icons and manuscripts dating back several centuries.",
    lat: 43.8588,
    lng: 18.4273,
    budget: :low,
    location_type: :place,
    tags: ["church", "orthodox", "museum", "historic"],
    suitable_experiences: ["religious", "history", "art"]
  },
  {
    name: "Jewish Museum Sarajevo",
    description: "Located in the old synagogue, showcasing the rich history of Sephardic Jews in Sarajevo.",
    historical_context: "The Sephardic Jewish community settled in Sarajevo in the 16th century after expulsion from Spain.",
    lat: 43.8590,
    lng: 18.4270,
    budget: :low,
    location_type: :place,
    tags: ["museum", "jewish", "history", "synagogue"],
    suitable_experiences: ["history", "culture", "religious"]
  },

  # Food & Drink
  {
    name: "Ćevabdžinica Željo",
    description: "Legendary ćevapi restaurant serving Sarajevo's most famous grilled meat dish since 1967.",
    lat: 43.8596,
    lng: 18.4314,
    budget: :low,
    location_type: :restaurant,
    tags: ["cevapi", "traditional", "bosnian-food", "legendary"],
    suitable_experiences: ["food", "meat"]
  },
  {
    name: "Inat Kuća (Spite House)",
    description: "Traditional Bosnian restaurant in a historic house with a fascinating story of defiance.",
    historical_context: "When Austro-Hungarian authorities wanted to demolish it for the City Hall, the owner had it moved stone by stone across the river.",
    lat: 43.8580,
    lng: 18.4350,
    budget: :medium,
    location_type: :restaurant,
    tags: ["traditional", "bosnian-food", "historic", "spite-house"],
    suitable_experiences: ["food", "history", "culture"]
  },
  {
    name: "Morica Han",
    description: "The only remaining han (inn) in Sarajevo, now a traditional Bosnian restaurant and tea house.",
    historical_context: "Built in 1551, Morica Han served as a resting place for travelers and merchants on the Silk Road.",
    lat: 43.8600,
    lng: 18.4303,
    budget: :medium,
    location_type: :restaurant,
    tags: ["traditional", "han", "historic", "coffee"],
    suitable_experiences: ["food", "history", "culture"]
  },
  {
    name: "Kafana Tito",
    description: "Popular kafana (tavern) with live traditional music and authentic Bosnian atmosphere.",
    lat: 43.8555,
    lng: 18.4180,
    budget: :medium,
    location_type: :restaurant,
    tags: ["kafana", "live-music", "nightlife", "traditional"],
    suitable_experiences: ["food", "nightlife", "culture"]
  },
  {
    name: "Buregdžinica Sač",
    description: "Famous burek shop using traditional sač (cooking under a metal dome) method.",
    lat: 43.8595,
    lng: 18.4300,
    budget: :low,
    location_type: :restaurant,
    tags: ["burek", "breakfast", "traditional", "cheap-eats"],
    suitable_experiences: ["food"]
  },
  {
    name: "Zlatna Ribica",
    description: "Quirky bar filled with antiques and curiosities, serving craft cocktails and local drinks.",
    lat: 43.8558,
    lng: 18.4200,
    budget: :medium,
    location_type: :restaurant,
    tags: ["bar", "cocktails", "unique", "nightlife"],
    suitable_experiences: ["nightlife", "culture"]
  },

  # Nature & Parks
  {
    name: "Vrelo Bosne",
    description: "Spring of the Bosna River, a beautiful park with crystal-clear waters, swans, and nature trails.",
    lat: 43.8190,
    lng: 18.2680,
    budget: :low,
    location_type: :place,
    tags: ["nature", "park", "spring", "walking", "family-friendly"],
    suitable_experiences: ["nature", "wellness"],
    video_url: "https://www.youtube.com/watch?v=agHtkA2ttM0"
  },
  {
    name: "Trebević Mountain",
    description: "Mountain overlooking Sarajevo with hiking trails, an abandoned Olympic bobsled track, and stunning views.",
    historical_context: "Site of the 1984 Winter Olympics bobsled and luge events. The track was damaged during the siege but has become a popular attraction.",
    lat: 43.8392,
    lng: 18.4508,
    budget: :low,
    location_type: :place,
    tags: ["mountain", "hiking", "olympics", "bobsled", "viewpoint"],
    suitable_experiences: ["nature", "sport", "mountains", "history"],
    video_url: "https://www.youtube.com/watch?v=agHtkA2ttM0"
  },
  {
    name: "Yellow Fortress (Žuta Tabija)",
    description: "Ottoman fortress offering the best panoramic views of Sarajevo, especially at sunset.",
    historical_context: "Built in the 18th century as part of Sarajevo's defense system.",
    lat: 43.8628,
    lng: 18.4381,
    budget: :low,
    location_type: :place,
    tags: ["viewpoint", "fortress", "sunset", "photography", "historic"],
    suitable_experiences: ["nature", "history", "culture"]
  },
  {
    name: "White Fortress (Bijela Tabija)",
    description: "Another Ottoman fortress with spectacular views over the old town.",
    historical_context: "Part of the same defensive system as Yellow Fortress, offering different perspectives of the city.",
    lat: 43.8640,
    lng: 18.4350,
    budget: :low,
    location_type: :place,
    tags: ["viewpoint", "fortress", "historic", "photography"],
    suitable_experiences: ["nature", "history", "culture"]
  },

  # Museums
  {
    name: "War Childhood Museum",
    description: "Powerful museum showcasing personal objects from children who grew up during the 1990s siege.",
    lat: 43.8554,
    lng: 18.4111,
    budget: :low,
    location_type: :place,
    tags: ["museum", "war", "moving", "history", "siege"],
    suitable_experiences: ["history", "culture", "art"]
  },
  {
    name: "Historical Museum of BiH",
    description: "National museum covering Bosnian history with exhibits on the siege and Yugoslav era.",
    lat: 43.8500,
    lng: 18.3930,
    budget: :low,
    location_type: :place,
    tags: ["museum", "history", "national"],
    suitable_experiences: ["history", "culture"]
  },
  {
    name: "Tunnel of Hope (Tunel Spasa)",
    description: "Underground tunnel used to smuggle supplies during the 1992-1996 siege, now a museum.",
    historical_context: "This 800m tunnel under the airport runway was Sarajevo's lifeline during the longest siege in modern history.",
    lat: 43.8181,
    lng: 18.3331,
    budget: :medium,
    location_type: :place,
    tags: ["museum", "war", "siege", "history", "tunnel"],
    suitable_experiences: ["history", "culture"],
    video_url: "https://www.youtube.com/watch?v=agHtkA2ttM0"
  },
  {
    name: "National Museum of BiH",
    description: "The oldest and largest museum in Bosnia, with archaeological, natural history, and ethnographic collections.",
    historical_context: "Founded in 1888, it houses the famous Sarajevo Haggadah, a 14th-century illuminated Jewish manuscript.",
    lat: 43.8510,
    lng: 18.3990,
    budget: :low,
    location_type: :place,
    tags: ["museum", "archaeology", "haggadah", "national"],
    suitable_experiences: ["history", "culture", "art"]
  },

  # Sports & Winter
  {
    name: "Jahorina Olympic Center",
    description: "Major ski resort that hosted 1984 Winter Olympics alpine skiing events.",
    lat: 43.7347,
    lng: 18.5681,
    budget: :high,
    location_type: :place,
    tags: ["skiing", "winter-sports", "olympics", "mountain"],
    suitable_experiences: ["sport", "mountains", "nature"]
  },
  {
    name: "Bjelašnica Ski Center",
    description: "Ski resort hosting 1984 Olympic alpine events, with excellent powder and fewer crowds.",
    lat: 43.7167,
    lng: 18.2667,
    budget: :high,
    location_type: :place,
    tags: ["skiing", "winter-sports", "olympics", "mountain"],
    suitable_experiences: ["sport", "mountains", "nature"]
  },
  {
    name: "Olympic Complex Zetra",
    description: "Ice skating arena built for 1984 Winter Olympics, now hosting sports events and concerts.",
    historical_context: "Originally built for figure skating and ice hockey, it was damaged during the siege and later rebuilt.",
    lat: 43.8450,
    lng: 18.3870,
    budget: :medium,
    location_type: :place,
    tags: ["sports", "olympics", "ice-skating", "concerts"],
    suitable_experiences: ["sport", "culture"]
  }
]

locations_data.each do |loc_data|
  location = Location.find_or_create_by!(name: loc_data[:name]) do |loc|
    loc.description = loc_data[:description]
    loc.historical_context = loc_data[:historical_context]
    loc.lat = loc_data[:lat]
    loc.lng = loc_data[:lng]
    loc.budget = loc_data[:budget]
    loc.location_type = loc_data[:location_type]
    loc.tags = loc_data[:tags] || []
    loc.suitable_experiences = loc_data[:suitable_experiences] || []
    loc.video_url = loc_data[:video_url]
    loc.city = "Sarajevo"
  end

  # Associate experience types
  if loc_data[:suitable_experiences].present?
    loc_data[:suitable_experiences].each do |exp_key|
      exp_type = ExperienceType.find_by(key: exp_key)
      location.add_experience_type(exp_type) if exp_type
    end
  end
end

puts "Created #{Location.count} locations"

# Seed Experiences
puts "Seeding experiences..."

experiences_data = [
  {
    title: "Ottoman Sarajevo Walking Tour",
    description: "Explore the rich Ottoman heritage of Sarajevo, from the iconic Baščaršija bazaar to magnificent mosques and hidden hans. Discover 500 years of history in this immersive walking tour.",
    estimated_duration: 180,
    category_key: "historical_walk",
    location_names: ["Baščaršija", "Sebilj Fountain", "Gazi Husrev-beg Mosque", "Morica Han"]
  },
  {
    title: "Sarajevo Food Adventure",
    description: "Taste your way through Sarajevo's culinary scene, from legendary ćevapi to sweet baklava. Experience the flavors that make Bosnian cuisine unique.",
    estimated_duration: 240,
    category_key: "foodie_tour",
    location_names: ["Ćevabdžinica Željo", "Buregdžinica Sač", "Morica Han", "Inat Kuća (Spite House)"]
  },
  {
    title: "Sarajevo's Siege History",
    description: "A moving journey through Sarajevo's recent history, visiting key sites from the 1992-1996 siege that shaped the city's resilience.",
    estimated_duration: 240,
    category_key: "historical_walk",
    location_names: ["Tunnel of Hope (Tunel Spasa)", "War Childhood Museum", "Historical Museum of BiH", "Latin Bridge"]
  },
  {
    title: "Religious Harmony Tour",
    description: "Discover how Sarajevo earned its nickname 'Jerusalem of Europe' by visiting mosques, churches, and a synagogue all within walking distance.",
    estimated_duration: 180,
    category_key: "religious_heritage",
    location_names: ["Gazi Husrev-beg Mosque", "Sacred Heart Cathedral", "Old Orthodox Church", "Jewish Museum Sarajevo"]
  },
  {
    title: "Sarajevo Panorama Hike",
    description: "Hike to Sarajevo's best viewpoints for stunning panoramas of the city nestled in its mountain valley. Visit Ottoman fortresses and catch an unforgettable sunset.",
    estimated_duration: 300,
    category_key: "nature_adventure",
    location_names: ["Yellow Fortress (Žuta Tabija)", "White Fortress (Bijela Tabija)", "Trebević Mountain"]
  },
  {
    title: "Olympic Winter Legacy",
    description: "Explore the venues and legacy of the 1984 Winter Olympics, from the iconic Zetra arena to mountain ski resorts.",
    estimated_duration: 360,
    category_key: "mountain_escape",
    location_names: ["Olympic Complex Zetra", "Trebević Mountain", "Jahorina Olympic Center"]
  },
  {
    title: "Sarajevo Art & Culture",
    description: "Immerse yourself in Sarajevo's vibrant cultural scene, from historic museums to architectural masterpieces.",
    estimated_duration: 240,
    category_key: "art_exploration",
    location_names: ["Sarajevo City Hall (Vijećnica)", "National Museum of BiH", "War Childhood Museum"]
  },
  {
    title: "Nature Escape to Vrelo Bosne",
    description: "Escape the city to the serene springs of the Bosna River. Enjoy a peaceful walk through lush parkland with crystal-clear waters.",
    estimated_duration: 180,
    category_key: "nature_adventure",
    location_names: ["Vrelo Bosne"]
  },
  {
    title: "Sarajevo Nightlife Experience",
    description: "Experience Sarajevo after dark, from quirky cocktail bars to traditional kafanas with live music.",
    estimated_duration: 240,
    category_key: "local_life",
    location_names: ["Zlatna Ribica", "Kafana Tito"]
  },
  {
    title: "Complete Sarajevo Heritage Tour",
    description: "A comprehensive tour covering Sarajevo's most significant historical and cultural landmarks, spanning Ottoman, Austro-Hungarian, and modern eras.",
    estimated_duration: 360,
    category_key: "cultural_heritage",
    location_names: ["Baščaršija", "Latin Bridge", "Sarajevo City Hall (Vijećnica)", "Gazi Husrev-beg Mosque", "Sacred Heart Cathedral"]
  }
]

experiences_data.each do |exp_data|
  category = ExperienceCategory.find_by(key: exp_data[:category_key])

  experience = Experience.find_or_create_by!(title: exp_data[:title]) do |exp|
    exp.description = exp_data[:description]
    exp.estimated_duration = exp_data[:estimated_duration]
    exp.experience_category = category
  end

  # Add locations to experience
  exp_data[:location_names].each_with_index do |loc_name, index|
    location = Location.find_by(name: loc_name)
    if location
      experience.add_location(location, position: index + 1)
    end
  end
end

puts "Created #{Experience.count} experiences"

# Attach images from picsum.photos
puts "Attaching images to locations and experiences..."

require "open-uri"
require "net/http"

def download_picsum_image(width: 800, height: 600, seed: nil)
  url = seed ? "https://picsum.photos/seed/#{seed}/#{width}/#{height}" : "https://picsum.photos/#{width}/#{height}"
  uri = URI.parse(url)

  # Follow redirect to get actual image
  response = Net::HTTP.get_response(uri)
  if response.is_a?(Net::HTTPRedirection)
    uri = URI.parse(response["location"])
    response = Net::HTTP.get_response(uri)
  end

  return nil unless response.is_a?(Net::HTTPSuccess)

  {
    io: StringIO.new(response.body),
    filename: "picsum_#{seed || SecureRandom.hex(4)}.jpg",
    content_type: "image/jpeg"
  }
rescue => e
  puts "  Failed to download image: #{e.message}"
  nil
end

# Attach cover photos to experiences
Experience.find_each do |experience|
  next if experience.cover_photo.attached?

  puts "  Attaching cover photo to: #{experience.title}"
  image_data = download_picsum_image(width: 1200, height: 800, seed: "exp_#{experience.id}")
  if image_data
    experience.cover_photo.attach(image_data)
  end
  sleep 0.3 # Rate limiting
end

# Attach photos to locations (1-3 photos each)
Location.find_each do |location|
  next if location.photos.attached?

  photo_count = rand(1..3)
  puts "  Attaching #{photo_count} photos to: #{location.name}"

  photo_count.times do |i|
    image_data = download_picsum_image(width: 800, height: 600, seed: "loc_#{location.id}_#{i}")
    if image_data
      location.photos.attach(image_data)
    end
    sleep 0.3 # Rate limiting
  end
end

puts "Attached images to #{Experience.joins(:cover_photo_attachment).count} experiences and #{Location.joins(:photos_attachments).distinct.count} locations"

# Attach audio recordings to some locations (for audio tour feature)
puts "Attaching audio recordings to locations..."

def download_sample_audio
  # Using a public domain audio sample from Internet Archive
  url = "https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg"
  uri = URI.parse(url)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)

  return nil unless response.is_a?(Net::HTTPSuccess)

  {
    io: StringIO.new(response.body),
    filename: "audio_tour.ogg",
    content_type: "audio/ogg"
  }
rescue => e
  puts "  Failed to download audio: #{e.message}"
  nil
end

# Attach audio to locations that have video_url (key locations) via AudioTour
locations_with_audio = Location.where.not(video_url: nil).limit(5)
locations_with_audio.each do |location|
  # Find or create audio tour for default locale
  audio_tour = location.audio_tours.find_or_initialize_by(locale: "bs")
  next if audio_tour.persisted? && audio_tour.audio_file.attached?

  puts "  Attaching audio tour to: #{location.name}"
  audio_data = download_sample_audio
  if audio_data
    audio_tour.save! if audio_tour.new_record?
    audio_tour.audio_file.attach(audio_data)
  end
  sleep 0.5
end

puts "Attached audio tours to #{Location.with_audio.count} locations"

# Seed Reviews
puts "Seeding reviews..."

review_comments = {
  5 => [
    "Absolutely amazing experience! Highly recommend to everyone.",
    "Best thing I did in Sarajevo. A must-visit!",
    "Exceeded all my expectations. Will definitely come back.",
    "Incredible! The history and atmosphere were unforgettable.",
    "Perfect experience. Our guide was knowledgeable and passionate."
  ],
  4 => [
    "Really enjoyed it. Great experience overall.",
    "Very good, though it could have been a bit longer.",
    "Wonderful place with rich history. Slightly crowded but worth it.",
    "Great experience, would recommend with minor improvements.",
    "Really nice! Beautiful location and friendly people."
  ],
  3 => [
    "It was okay. Not bad but not exceptional either.",
    "Decent experience. Expected a bit more based on reviews.",
    "Average. Some parts were great, others not so much.",
    "Nice place but nothing too special compared to similar spots.",
    "Okay experience. Good for a quick visit."
  ]
}

author_names = [
  "Anna K.", "Marco T.", "Sarah B.", "Thomas M.", "Elena V.",
  "David R.", "Sophie L.", "James H.", "Maria G.", "Peter W.",
  "Laura S.", "Michael C.", "Julia F.", "Robert N.", "Emma D."
]

# Add reviews to locations
Location.all.each do |location|
  rand(3..8).times do
    rating = [5, 5, 5, 4, 4, 4, 4, 3].sample
    comment = review_comments[rating].sample

    Review.create!(
      reviewable: location,
      rating: rating,
      comment: comment,
      author_name: author_names.sample,
      created_at: rand(1..180).days.ago
    )
  end
end

# Add reviews to experiences
Experience.all.each do |experience|
  rand(2..5).times do
    rating = [5, 5, 4, 4, 4, 3].sample
    comment = review_comments[rating].sample

    Review.create!(
      reviewable: experience,
      rating: rating,
      comment: comment,
      author_name: author_names.sample,
      created_at: rand(1..90).days.ago
    )
  end
end

puts "Created #{Review.count} reviews"

puts "Seeding complete!"
puts ""
puts "=== Demo Accounts ==="
puts "Curator: username: curator, password: curator123"
puts "User:    username: user,    password: user123"
puts "====================="

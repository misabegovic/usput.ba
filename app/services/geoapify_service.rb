# Service for interacting with Geoapify Places API
# https://apidocs.geoapify.com/docs/places/
class GeoapifyService
  class ApiError < StandardError; end
  class ConfigurationError < StandardError; end

  BASE_URL = "https://api.geoapify.com/v2".freeze
  PLACE_DETAILS_URL = "https://api.geoapify.com/v2/place-details".freeze

  # Categories to EXCLUDE from search results
  # Includes retirement homes, social facilities, and soup kitchens not relevant for tourism
  EXCLUDED_CATEGORIES = %w[
    service.social_facility
    service.social_facility.food_bank
    service.social_facility.soup_kitchen
    amenity.social_facility
    healthcare.nursing_home
    healthcare.assisted_living
    healthcare.retirement_home
    building.residential
  ].freeze

  # Keywords in place names/descriptions to exclude (case-insensitive)
  EXCLUDED_NAME_KEYWORDS = %w[
    penzioner
    retirement
    nursing
    starački
    gerontološki
    gerontoloski
    dom za stare
    dom za starije
    elderly
    seniorski
    aged care
    soup kitchen
    narodna kuhinja
    pučka kuhinja
    javna kuhinja
    socijalna kuhinja
    food bank
    banka hrane
    humanitarna pomoć
    humanitarna pomoc
    besplatna hrana
    socijalni centar
    centar za socijalnu pomoć
    centar za socijalnu pomoc
  ].freeze

  # Default tourism categories (fallback if database is empty)
  # Complete list of all Geoapify categories
  # NOTE: Accommodation categories significantly reduced per user request
  DEFAULT_TOURISM_CATEGORIES = %w[
    accommodation.hotel
    camping
    camping.camp_site
    activity
    activity.community_center
    building.historic
    building.tourism
    catering
    catering.restaurant
    catering.cafe
    catering.fast_food
    catering.bar
    catering.pub
    catering.biergarten
    catering.taproom
    catering.ice_cream
    commercial.marketplace
    commercial.shopping_mall
    commercial.books
    commercial.antiques
    commercial.art
    commercial.food_and_drink
    commercial.food_and_drink.bakery
    commercial.food_and_drink.deli
    commercial.food_and_drink.wine
    education.library
    education.university
    entertainment
    entertainment.culture
    entertainment.culture.theatre
    entertainment.culture.gallery
    entertainment.culture.arts_centre
    entertainment.culture.cultural_center
    entertainment.museum
    entertainment.cinema
    entertainment.casino
    entertainment.night_club
    entertainment.zoo
    entertainment.aquarium
    entertainment.theme_park
    entertainment.water_park
    entertainment.planetarium
    entertainment.bowling_alley
    entertainment.amusement_arcade
    healthcare.hospital
    healthcare.pharmacy
    heritage
    heritage.unesco
    leisure
    leisure.park
    leisure.playground
    leisure.garden
    leisure.spa
    leisure.sauna
    leisure.marina
    leisure.swimming_area
    man_made.bridge
    man_made.lighthouse
    man_made.pier
    man_made.tower
    man_made.watermill
    man_made.windmill
    national_park
    natural
    natural.forest
    natural.water
    natural.water.sea
    natural.water.spring
    natural.water.reef
    natural.water.hot_spring
    natural.water.geyser
    natural.mountain.peak
    natural.mountain.glacier
    natural.mountain.cliff
    natural.mountain.rock
    natural.mountain.cave_entrance
    natural.sand.dune
    natural.protected_area
    beach
    beach.beach_resort
    production.brewery
    production.winery
    production.distillery
    public_transport.train.station
    public_transport.ferry
    public_transport.airport
    religion
    religion.place_of_worship
    religion.place_of_worship.christianity
    religion.place_of_worship.islam
    religion.place_of_worship.judaism
    religion.place_of_worship.buddhism
    religion.place_of_worship.hinduism
    religion.place_of_worship.shinto
    religion.place_of_worship.sikhism
    religion.place_of_worship.multifaith
    tourism.sights.place_of_worship
    tourism.sights.place_of_worship.mosque
    tourism.sights.place_of_worship.church
    tourism.sights.place_of_worship.chapel
    tourism.sights.place_of_worship.cathedral
    tourism.sights.place_of_worship.synagogue
    tourism.sights.place_of_worship.temple
    tourism.sights.place_of_worship.shrine
    service.townhall
    service.embassy
    ski
    ski.resort
    sport
    sport.stadium
    sport.sports_centre
    sport.swimming_pool
    sport.ice_rink
    sport.fitness
    sport.golf
    sport.tennis
    sport.climbing
    sport.equestrian
    sport.diving
    sport.water_sports
    sport.sailing
    sport.skiing
    tourism
    tourism.attraction
    tourism.sights
    tourism.sights.memorial
    tourism.sights.tower
    tourism.sights.windmill
    tourism.sights.watermill
    tourism.sights.fort
    tourism.sights.castle
    tourism.sights.palace
    tourism.sights.manor
    tourism.sights.ruines
    tourism.sights.archaeological_site
    tourism.sights.city_gate
    tourism.sights.battlefield
    tourism.sights.monastery
    tourism.sights.statue
    tourism.information
    tourism.information.office
    tourism.information.visitor_centre
    tourism.viewpoint
    tourism.artwork
    tourism.artwork.sculpture
    tourism.artwork.mural
    tourism.alpine_hut
    tourism.picnic_site
    tourism.camp_site
  ].freeze

  # Default mapping from Geoapify categories to simplified types (fallback)
  # Comprehensive mapping for all supported categories
  DEFAULT_CATEGORY_TYPE_MAPPING = {
    # Accommodation
    "accommodation" => "lodging",
    "accommodation.hotel" => "hotel",
    "accommodation.hut" => "lodging",
    "accommodation.apartment" => "apartment",
    "accommodation.chalet" => "lodging",
    "accommodation.guest_house" => "guest_house",
    "accommodation.hostel" => "hostel",
    "accommodation.motel" => "motel",

    # Camping
    "camping" => "campground",
    "camping.camp_pitch" => "campground",
    "camping.camp_site" => "campground",
    "camping.summer_camp" => "campground",
    "camping.caravan_site" => "rv_park",

    # Activity
    "activity" => "community_center",
    "activity.community_center" => "community_center",
    "activity.sport_club" => "sports_club",

    # Building
    "building" => "building",
    "building.historic" => "historical_landmark",
    "building.tourism" => "tourist_attraction",
    "building.commercial" => "shopping_mall",
    "building.public" => "government_office",

    # Catering
    "catering" => "restaurant",
    "catering.restaurant" => "restaurant",
    "catering.restaurant.pizza" => "pizza_restaurant",
    "catering.restaurant.burger" => "hamburger_restaurant",
    "catering.restaurant.regional" => "restaurant",
    "catering.restaurant.italian" => "italian_restaurant",
    "catering.restaurant.chinese" => "chinese_restaurant",
    "catering.restaurant.japanese" => "japanese_restaurant",
    "catering.restaurant.indian" => "indian_restaurant",
    "catering.restaurant.thai" => "thai_restaurant",
    "catering.restaurant.mexican" => "mexican_restaurant",
    "catering.restaurant.kebab" => "middle_eastern_restaurant",
    "catering.restaurant.seafood" => "seafood_restaurant",
    "catering.restaurant.steak_house" => "steak_house",
    "catering.restaurant.sushi" => "sushi_restaurant",
    "catering.restaurant.ramen" => "ramen_restaurant",
    "catering.restaurant.vietnamese" => "vietnamese_restaurant",
    "catering.restaurant.korean" => "korean_restaurant",
    "catering.restaurant.greek" => "greek_restaurant",
    "catering.restaurant.french" => "french_restaurant",
    "catering.restaurant.spanish" => "spanish_restaurant",
    "catering.restaurant.turkish" => "turkish_restaurant",
    "catering.restaurant.american" => "american_restaurant",
    "catering.cafe" => "cafe",
    "catering.cafe.coffee_shop" => "coffee_shop",
    "catering.cafe.coffee" => "coffee_shop",
    "catering.cafe.tea" => "tea_house",
    "catering.fast_food" => "fast_food_restaurant",
    "catering.fast_food.pizza" => "pizza_restaurant",
    "catering.fast_food.burger" => "hamburger_restaurant",
    "catering.fast_food.sandwich" => "sandwich_shop",
    "catering.fast_food.kebab" => "middle_eastern_restaurant",
    "catering.fast_food.ice_cream" => "ice_cream_shop",
    "catering.bar" => "bar",
    "catering.bar.wine" => "wine_bar",
    "catering.bar.cocktail" => "cocktail_bar",
    "catering.bar.beer" => "bar",
    "catering.bar.sports" => "sports_bar",
    "catering.pub" => "pub",
    "catering.biergarten" => "beer_garden",
    "catering.taproom" => "brewery",
    "catering.food_court" => "food_court",
    "catering.ice_cream" => "ice_cream_shop",

    # Commercial
    "commercial" => "shopping",
    "commercial.supermarket" => "supermarket",
    "commercial.marketplace" => "market",
    "commercial.shopping_mall" => "shopping_mall",
    "commercial.department_store" => "department_store",
    "commercial.clothing" => "clothing_store",
    "commercial.jewelry" => "jewelry_store",
    "commercial.books" => "book_store",
    "commercial.gift" => "gift_shop",
    "commercial.antiques" => "antique_store",
    "commercial.art" => "art_gallery",
    "commercial.food_and_drink" => "grocery_store",
    "commercial.food_and_drink.bakery" => "bakery",
    "commercial.food_and_drink.deli" => "deli",
    "commercial.food_and_drink.butcher" => "butcher",
    "commercial.food_and_drink.wine" => "wine_store",
    "commercial.florist" => "florist",
    "commercial.electronics" => "electronics_store",
    "commercial.convenience" => "convenience_store",

    # Education
    "education" => "school",
    "education.school" => "school",
    "education.university" => "university",
    "education.college" => "college",
    "education.library" => "library",
    "education.kindergarten" => "preschool",
    "education.music_school" => "music_school",

    # Entertainment
    "entertainment" => "entertainment",
    "entertainment.culture" => "performing_arts_theater",
    "entertainment.culture.theatre" => "theater",
    "entertainment.culture.gallery" => "art_gallery",
    "entertainment.culture.arts_centre" => "arts_center",
    "entertainment.culture.cultural_center" => "cultural_center",
    "entertainment.museum" => "museum",
    "entertainment.cinema" => "movie_theater",
    "entertainment.casino" => "casino",
    "entertainment.night_club" => "night_club",
    "entertainment.zoo" => "zoo",
    "entertainment.aquarium" => "aquarium",
    "entertainment.theme_park" => "amusement_park",
    "entertainment.water_park" => "water_park",
    "entertainment.planetarium" => "planetarium",
    "entertainment.escape_game" => "escape_room",
    "entertainment.bowling_alley" => "bowling_alley",
    "entertainment.amusement_arcade" => "amusement_arcade",
    "entertainment.miniature_golf" => "miniature_golf",
    "entertainment.laser_tag" => "laser_tag",

    # Healthcare
    "healthcare" => "hospital",
    "healthcare.hospital" => "hospital",
    "healthcare.clinic" => "clinic",
    "healthcare.dentist" => "dentist",
    "healthcare.pharmacy" => "pharmacy",
    "healthcare.veterinary" => "veterinarian",

    # Heritage
    "heritage" => "heritage_site",
    "heritage.unesco" => "unesco_world_heritage",

    # Leisure
    "leisure" => "park",
    "leisure.park" => "park",
    "leisure.playground" => "playground",
    "leisure.garden" => "garden",
    "leisure.dog_park" => "dog_park",
    "leisure.picnic" => "picnic_area",
    "leisure.spa" => "spa",
    "leisure.sauna" => "sauna",
    "leisure.marina" => "marina",
    "leisure.swimming_area" => "swimming_area",

    # Man-made
    "man_made" => "landmark",
    "man_made.bridge" => "bridge",
    "man_made.lighthouse" => "lighthouse",
    "man_made.pier" => "pier",
    "man_made.tower" => "tower",
    "man_made.watermill" => "watermill",
    "man_made.windmill" => "windmill",
    "man_made.water_tower" => "water_tower",

    # National park
    "national_park" => "national_park",

    # Natural (valid Geoapify categories)
    "natural" => "nature",
    "natural.forest" => "forest",
    "natural.water" => "water_body",
    "natural.water.sea" => "sea",
    "natural.water.spring" => "spring",
    "natural.water.reef" => "reef",
    "natural.water.hot_spring" => "hot_spring",
    "natural.water.geyser" => "geyser",
    "natural.mountain" => "mountain",
    "natural.mountain.peak" => "mountain_peak",
    "natural.mountain.glacier" => "glacier",
    "natural.mountain.cliff" => "cliff",
    "natural.mountain.rock" => "rock_formation",
    "natural.mountain.cave_entrance" => "cave",
    "natural.sand" => "sand",
    "natural.sand.dune" => "sand_dune",
    "natural.protected_area" => "protected_area",

    # Beach (valid Geoapify categories - separate from natural)
    "beach" => "beach",
    "beach.beach_resort" => "beach_resort",

    # Office
    "office" => "office",
    "office.government" => "government_office",
    "office.travel_agent" => "travel_agency",

    # Parking
    "parking" => "parking",
    "parking.cars" => "parking_lot",

    # Production
    "production" => "factory",
    "production.brewery" => "brewery",
    "production.winery" => "winery",
    "production.distillery" => "distillery",
    "production.cheese" => "cheese_factory",
    "production.chocolate" => "chocolate_factory",

    # Public Transport
    "public_transport" => "transit_station",
    "public_transport.train" => "train_station",
    "public_transport.train.station" => "train_station",
    "public_transport.bus" => "bus_station",
    "public_transport.subway" => "subway_station",
    "public_transport.ferry" => "ferry_terminal",
    "public_transport.airport" => "airport",

    # Rental
    "rental" => "rental",
    "rental.bicycle" => "bicycle_rental",
    "rental.car" => "car_rental",
    "rental.boat" => "boat_rental",

    # Religion (by religion name - valid Geoapify categories)
    "religion" => "place_of_worship",
    "religion.place_of_worship" => "place_of_worship",
    "religion.place_of_worship.christianity" => "church",
    "religion.place_of_worship.islam" => "mosque",
    "religion.place_of_worship.judaism" => "synagogue",
    "religion.place_of_worship.buddhism" => "buddhist_temple",
    "religion.place_of_worship.hinduism" => "hindu_temple",
    "religion.place_of_worship.shinto" => "shinto_shrine",
    "religion.place_of_worship.sikhism" => "sikh_temple",
    "religion.place_of_worship.multifaith" => "place_of_worship",

    # Tourism sights - places of worship (by building type - valid Geoapify categories)
    "tourism.sights.place_of_worship" => "place_of_worship",
    "tourism.sights.place_of_worship.mosque" => "mosque",
    "tourism.sights.place_of_worship.church" => "church",
    "tourism.sights.place_of_worship.chapel" => "chapel",
    "tourism.sights.place_of_worship.cathedral" => "cathedral",
    "tourism.sights.place_of_worship.synagogue" => "synagogue",
    "tourism.sights.place_of_worship.temple" => "temple",
    "tourism.sights.place_of_worship.shrine" => "shrine",

    # Service
    "service" => "service",
    "service.financial.bank" => "bank",
    "service.financial.atm" => "atm",
    "service.post_office" => "post_office",
    "service.police" => "police_station",
    "service.fire_station" => "fire_station",
    "service.embassy" => "embassy",
    "service.townhall" => "city_hall",
    "service.community_centre" => "community_center",
    "service.travel_agency" => "travel_agency",
    "service.beauty.spa" => "spa",
    "service.beauty.hairdresser" => "hair_salon",

    # Ski
    "ski" => "ski_resort",
    "ski.resort" => "ski_resort",
    "ski.lift" => "ski_lift",

    # Sport
    "sport" => "sports_facility",
    "sport.stadium" => "stadium",
    "sport.sports_centre" => "sports_center",
    "sport.swimming_pool" => "swimming_pool",
    "sport.ice_rink" => "ice_rink",
    "sport.fitness" => "gym",
    "sport.golf" => "golf_course",
    "sport.golf.course" => "golf_course",
    "sport.tennis" => "tennis_court",
    "sport.basketball" => "basketball_court",
    "sport.soccer" => "soccer_field",
    "sport.volleyball" => "volleyball_court",
    "sport.climbing" => "climbing_gym",
    "sport.climbing.outdoor" => "climbing_area",
    "sport.equestrian" => "equestrian_facility",
    "sport.horse_racing" => "horse_racing_track",
    "sport.diving" => "diving_center",
    "sport.water_sports" => "water_sports_center",
    "sport.sailing" => "sailing_club",
    "sport.skiing" => "ski_resort",
    "sport.bowling" => "bowling_alley",
    "sport.yoga" => "yoga_studio",
    "sport.martial_arts" => "martial_arts_school",

    # Tourism
    "tourism" => "tourist_attraction",
    "tourism.attraction" => "tourist_attraction",
    "tourism.sights" => "historical_landmark",
    "tourism.sights.memorial" => "memorial",
    "tourism.sights.tower" => "observation_tower",
    "tourism.sights.windmill" => "windmill",
    "tourism.sights.watermill" => "watermill",
    "tourism.sights.fort" => "fort",
    "tourism.sights.castle" => "castle",
    "tourism.sights.palace" => "palace",
    "tourism.sights.manor" => "manor",
    "tourism.sights.ruines" => "ruins",
    "tourism.sights.archaeological_site" => "archaeological_site",
    "tourism.sights.city_gate" => "city_gate",
    "tourism.sights.battlefield" => "battlefield",
    "tourism.sights.monastery" => "monastery",
    "tourism.sights.statue" => "statue",
    "tourism.sights.aircraft" => "aircraft_exhibit",
    "tourism.sights.locomotive" => "locomotive_exhibit",
    "tourism.sights.ship" => "ship_exhibit",
    "tourism.information" => "tourist_information",
    "tourism.information.office" => "tourist_information",
    "tourism.information.visitor_centre" => "visitor_center",
    "tourism.viewpoint" => "viewpoint",
    "tourism.artwork" => "public_art",
    "tourism.artwork.sculpture" => "sculpture",
    "tourism.artwork.mural" => "mural",
    "tourism.artwork.street_art" => "street_art",
    "tourism.alpine_hut" => "alpine_hut",
    "tourism.picnic_site" => "picnic_site",
    "tourism.camp_site" => "campground",
    "tourism.caravan_site" => "rv_park",
    "tourism.wilderness_hut" => "wilderness_hut"
  }.freeze

  def initialize
    @api_key = Rails.application.config.geoapify.api_key
    raise ConfigurationError, "Geoapify API key not configured" if @api_key.blank?

    @connection = Faraday.new(url: BASE_URL) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end
  end

  # Search for places near a location
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @param radius [Integer] Radius in meters (default from settings)
  # @param types [Array<String>] Place types to search for (Google types, will be converted)
  # @param max_results [Integer] Maximum number of results
  # @return [Array<Hash>] Array of place data
  def search_nearby(lat:, lng:, radius: nil, types: nil, max_results: nil)
    radius ||= default_radius
    max_results ||= default_max_results
    categories = types ? convert_types_to_categories(types) : tourism_categories

    places = []
    batch_size = Setting.get("geoapify.batch_size", default: 5)

    # Search with all categories at once (Geoapify supports multiple categories)
    categories.each_slice(batch_size) do |category_batch|
      break if places.size >= max_results

      response = get_places(
        categories: category_batch,
        filter: "circle:#{lng},#{lat},#{radius}",
        limit: [ max_results - places.size, api_limit ].min
      )

      if response["features"]
        response["features"].each do |feature|
          places << parse_place(feature)
        end
      end
    end

    # Filter out excluded places (retirement homes, social facilities, etc.)
    filtered_places = places.reject { |place| excluded_place?(place) }
    filtered_places.uniq { |p| p[:place_id] }.first(max_results)
  end

  # Search for places by text query
  # @param query [String] Search query
  # @param lat [Float] Optional center latitude for bias
  # @param lng [Float] Optional center longitude for bias
  # @param radius [Integer] Radius in meters for location bias
  # @return [Array<Hash>] Array of place data
  def text_search(query:, lat: nil, lng: nil, radius: nil, max_results: nil)
    radius ||= default_radius
    max_results ||= Setting.get("geoapify.text_search_max_results", default: 20)

    params = {
      text: query,
      limit: max_results,
      lang: default_language,
      apiKey: @api_key
    }

    if lat && lng
      params[:bias] = "proximity:#{lng},#{lat}"
    end

    # Use geocoding API for text search
    geocode_connection = Faraday.new(url: "https://api.geoapify.com/v1/geocode") do |faraday|
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end

    response = geocode_connection.get("search") do |req|
      req.params = params
    end

    handle_response(response)

    return [] unless response.body["features"]

    places = response.body["features"].map { |feature| parse_geocode_result(feature) }
    # Filter out excluded places (retirement homes, social facilities, etc.)
    places.reject { |place| excluded_place?(place) }
  end

  # Get detailed information about a place
  # @param place_id [String] Geoapify Place ID
  # @return [Hash] Place details
  def get_place_details(place_id)
    connection = Faraday.new(url: PLACE_DETAILS_URL) do |faraday|
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end

    response = connection.get("") do |req|
      req.params = {
        id: place_id,
        features: "details",
        apiKey: @api_key
      }
    end

    handle_response(response)

    return {} unless response.body["features"]&.any?

    parse_place_details(response.body["features"].first)
  end

  # Get photo URL for a place
  # Note: Geoapify doesn't provide photos directly like Google Places
  # We'll return nil and handle photo fetching differently
  # @param photo_reference [String] Photo reference (not used with Geoapify)
  # @param max_width [Integer] Maximum width in pixels
  # @param max_height [Integer] Maximum height in pixels
  # @return [String, nil] Photo URL or nil
  def get_photo_url(photo_reference, max_width: 800, max_height: 600)
    # Geoapify doesn't provide place photos in the same way as Google
    # Return nil - photos will need to be sourced elsewhere
    nil
  end

  # Reverse geocode coordinates to get address information
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @return [Hash] Address data including city, country, etc.
  def reverse_geocode(lat:, lng:)
    geocode_connection = Faraday.new(url: "https://api.geoapify.com/v1/geocode") do |faraday|
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end

    response = geocode_connection.get("reverse") do |req|
      req.params = {
        lat: lat,
        lon: lng,
        lang: default_language,
        apiKey: @api_key
      }
    end

    handle_response(response)

    return {} unless response.body["features"]&.any?

    parse_reverse_geocode_result(response.body["features"].first)
  rescue StandardError => e
    Rails.logger.warn "[GeoapifyService] Reverse geocoding failed for #{lat}, #{lng}: #{e.message}"
    {}
  end

  # Extract city name from coordinates using reverse geocoding
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @return [String, nil] City name or nil
  def get_city_from_coordinates(lat, lng)
    result = reverse_geocode(lat: lat, lng: lng)
    return nil if result.blank?

    # Priority: city > town > village > suburb > municipality
    city_name = result[:city] ||
                result[:town] ||
                result[:village] ||
                result[:suburb] ||
                result[:municipality] ||
                result[:county]

    return nil if city_name.blank?

    # Clean up city name (remove administrative prefixes)
    city_name.to_s
             .gsub(/^Grad\s+/i, "")
             .gsub(/^Općina\s+/i, "")
             .gsub(/^Opština\s+/i, "")
             .gsub(/^Miasto\s+/i, "")
             .gsub(/^City of\s+/i, "")
             .gsub(/^Municipality of\s+/i, "")
             .strip
  end

  private

  def parse_reverse_geocode_result(feature)
    properties = feature["properties"] || {}

    {
      formatted: properties["formatted"],
      city: properties["city"],
      town: properties["town"],
      village: properties["village"],
      suburb: properties["suburb"],
      municipality: properties["municipality"],
      county: properties["county"],
      state: properties["state"],
      country: properties["country"],
      country_code: properties["country_code"],
      postcode: properties["postcode"],
      street: properties["street"],
      housenumber: properties["housenumber"],
      lat: properties["lat"],
      lng: properties["lon"]
    }
  end

  # Get tourism categories - uses comprehensive defaults
  # Note: GeoapifyCategory model doesn't exist, using DEFAULT_TOURISM_CATEGORIES
  def tourism_categories
    @tourism_categories ||= DEFAULT_TOURISM_CATEGORIES
  end

  # Get category type mapping - uses comprehensive defaults
  # Note: GeoapifyCategory model doesn't exist, using DEFAULT_CATEGORY_TYPE_MAPPING
  def category_type_mapping
    @category_type_mapping ||= DEFAULT_CATEGORY_TYPE_MAPPING
  end

  # Check if a place should be excluded from results
  # Excludes retirement homes, social facilities, and similar non-tourism places
  # @param place [Hash] Parsed place data
  # @return [Boolean] true if place should be excluded
  def excluded_place?(place)
    return false if place.blank?

    # Check if any of the place's categories are in the excluded list
    place_categories = place[:types] || []
    if place_categories.any? { |cat| EXCLUDED_CATEGORIES.any? { |exc| cat.to_s.include?(exc) } }
      Rails.logger.debug "[GeoapifyService] Excluding place by category: #{place[:name]}"
      return true
    end

    # Check if the place name contains excluded keywords
    place_name = place[:name].to_s.downcase
    place_address = place[:address].to_s.downcase
    combined_text = "#{place_name} #{place_address}"

    if EXCLUDED_NAME_KEYWORDS.any? { |keyword| combined_text.include?(keyword.downcase) }
      Rails.logger.debug "[GeoapifyService] Excluding place by name keyword: #{place[:name]}"
      return true
    end

    false
  end

  # Configurable settings
  def default_radius
    Setting.get("geoapify.default_radius", default: 10_000)
  end

  def default_max_results
    Setting.get("geoapify.default_max_results", default: 50)
  end

  def api_limit
    Setting.get("geoapify.api_limit", default: 100)
  end

  def default_language
    Setting.get("geoapify.default_language", default: "en")
  end

  def get_places(categories:, filter:, limit:, offset: 0)
    response = @connection.get("places") do |req|
      req.params = {
        categories: categories.join(","),
        filter: filter,
        limit: limit,
        offset: offset,
        lang: default_language,
        apiKey: @api_key
      }
    end

    handle_response(response)
    response.body
  end

  def handle_response(response)
    unless response.success?
      error_message = response.body.is_a?(Hash) ? response.body["message"] : "Unknown error"
      raise ApiError, "Geoapify API error (#{response.status}): #{error_message}"
    end

    response.body
  end

  def convert_types_to_categories(types)
    # Convert Google Places types to Geoapify categories
    type_to_category = category_type_mapping.invert

    types.filter_map do |type|
      type_to_category[type] || find_matching_category(type)
    end.presence || tourism_categories
  end

  def find_matching_category(type)
    # Try to find a matching category based on partial match
    case type
    when /restaurant/ then "catering.restaurant"
    when /cafe/ then "catering.cafe"
    when /bar/ then "catering.bar"
    when /museum/ then "entertainment.museum"
    when /park/ then "leisure.park"
    when /church|chapel|cathedral/ then "tourism.sights.place_of_worship.church"
    when /mosque/ then "tourism.sights.place_of_worship.mosque"
    when /synagogue/ then "tourism.sights.place_of_worship.synagogue"
    when /temple/ then "tourism.sights.place_of_worship.temple"
    when /theater|theatre/ then "entertainment.culture.theatre"
    when /zoo/ then "entertainment.zoo"
    when /aquarium/ then "entertainment.aquarium"
    when /beach/ then "beach"
    when /stadium/ then "sport.stadium"
    when /hotel|lodging/ then "accommodation.hotel"
    when /historic|landmark|monument/ then "tourism.sights"
    else nil
    end
  end

  def parse_place(feature)
    return {} if feature.blank?

    properties = feature["properties"] || {}
    geometry = feature["geometry"] || {}
    coordinates = geometry["coordinates"] || []

    categories = properties["categories"] || []
    primary_category = categories.first
    mapping = category_type_mapping

    {
      place_id: properties["place_id"],
      name: properties["name"] || properties["address_line1"],
      address: properties["formatted"] || build_address(properties),
      lat: coordinates[1],
      lng: coordinates[0],
      types: categories.map { |c| mapping[c] || c.split(".").last },
      primary_type: mapping[primary_category] || primary_category&.split(".")&.last,
      primary_type_display: format_category_display(primary_category),
      description: properties["description"],
      rating: properties["rating"],
      rating_count: properties["rating_count"],
      price_level: parse_price_level(properties["price_level"]),
      website: properties["website"],
      phone: properties["phone"] || properties["contact"]&.dig("phone"),
      photos: [],  # Geoapify doesn't provide photos in Places API
      opening_hours: parse_opening_hours(properties["opening_hours"]),
      datasource: properties["datasource"]
    }
  end

  def parse_geocode_result(feature)
    properties = feature["properties"] || {}
    {
      place_id: properties["place_id"],
      name: properties["name"] || properties["address_line1"],
      address: properties["formatted"],
      lat: properties["lat"],
      lng: properties["lon"],
      types: [ properties["category"] ].compact,
      primary_type: properties["category"],
      primary_type_display: properties["category"]&.titleize,
      description: nil,
      rating: nil,
      rating_count: nil,
      price_level: :medium,
      website: nil,
      phone: nil,
      photos: [],
      opening_hours: nil
    }
  end

  def parse_place_details(feature)
    properties = feature["properties"] || {}
    geometry = feature["geometry"] || {}

    # Handle both point and polygon geometries
    coordinates = case geometry["type"]
    when "Point"
      geometry["coordinates"]
    when "Polygon", "MultiPolygon"
      # Get centroid from first coordinate
      geometry["coordinates"]&.flatten(2)&.first(2)
    else
      []
    end

    categories = properties["categories"] || []
    wiki = properties["wiki_and_media"] || {}
    mapping = category_type_mapping

    {
      place_id: properties["place_id"],
      name: properties["name"] || properties["address_line1"],
      address: properties["formatted"],
      lat: coordinates&.at(1),
      lng: coordinates&.at(0),
      types: categories.map { |c| mapping[c] || c.split(".").last },
      primary_type: mapping[categories.first] || categories.first&.split(".")&.last,
      primary_type_display: format_category_display(categories.first),
      description: wiki["description"] || properties["description"],
      rating: properties["rating"],
      rating_count: properties["rating_count"],
      price_level: parse_price_level(properties["price_level"]),
      website: properties["website"] || wiki["wikipedia"],
      phone: properties.dig("contact", "phone"),
      photos: parse_wiki_images(wiki),
      opening_hours: parse_opening_hours(properties["opening_hours"]),
      wikipedia: wiki["wikipedia"],
      wikidata: wiki["wikidata"]
    }
  end

  def build_address(properties)
    [
      properties["street"],
      properties["housenumber"],
      properties["city"],
      properties["country"]
    ].compact.join(", ")
  end

  def format_category_display(category)
    return nil if category.blank?

    category.split(".").last.titleize.gsub("_", " ")
  end

  def parse_price_level(level)
    case level.to_s.downcase
    when "cheap", "inexpensive", "1" then :low
    when "moderate", "2" then :medium
    when "expensive", "3", "4" then :high
    else :medium
    end
  end

  def parse_opening_hours(hours)
    return nil if hours.blank?

    {
      open_now: nil,  # Geoapify doesn't provide real-time open status
      weekday_text: hours.is_a?(String) ? [ hours ] : hours
    }
  end

  def parse_wiki_images(wiki)
    return [] if wiki.blank?

    images = []

    if wiki["image"]
      images << {
        name: wiki["image"],
        url: wiki["image"],
        width: nil,
        height: nil,
        attributions: [ "Wikimedia Commons" ]
      }
    end

    images
  end
end

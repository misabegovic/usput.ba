class PlansController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_explore

  # Plan generation constants
  DEFAULT_DAILY_HOURS = 6        # Default hours of active tourism per day
  MIN_DAILY_HOURS = 2            # Minimum allowed daily hours
  MAX_DAILY_HOURS = 12           # Maximum allowed daily hours
  DEFAULT_EXPERIENCE_DURATION = 60  # Default duration if not specified (minutes)

  # GET /plans/:id
  def show
    @plan = Plan.includes(plan_experiences: { experience: :locations }).find_by_public_id!(params[:id])

    # Only allow viewing public plans, or own plans if logged in
    unless @plan.visibility_public_plan? || (logged_in? && @plan.user_id == current_user.id)
      raise ActiveRecord::RecordNotFound
    end

    @reviews = @plan.reviews.recent.limit(10)
    @review = Review.new
  end

  # GET /plans/wizard
  def wizard
    @city_name = params[:city_name] if params[:city_name].present?
    @supported_interests = ExperienceType.active_keys
  end

  # GET /plans/view
  # Prikaži generirani plan iz localStorage-a (client-side)
  def view
    # Plan se čita iz localStorage-a na klijentskoj strani
    # Ova akcija samo renderira prazan template koji JS popunjava
  end

  # POST /plans/find_city
  # Pronađi najbliži grad na temelju koordinata (iz lokacija)
  def find_city
    lat = params[:lat].to_f
    lng = params[:lng].to_f

    # Find nearest location with a city name
    nearest_location = Location.with_coordinates
                               .where.not(city: [nil, ""])
                               .near([lat, lng], 100, units: :km)
                               .first

    if nearest_location
      render json: {
        city_name: nearest_location.city,
        location: {
          id: nearest_location.uuid,
          name: nearest_location.name,
          city: nearest_location.city
        }
      }
    else
      render json: { city_name: nil, error: "No locations found nearby" }, status: :not_found
    end
  end

  # GET /plans/search_cities
  # Pretraži gradove po imenu (iz lokacija)
  def search_cities
    query = params[:q].to_s.strip

    if query.length < 2
      render json: { cities: [] }
      return
    end

    # Get distinct city names from locations
    city_names = Location.where("city ILIKE ?", "%#{query}%")
                         .where.not(city: [nil, ""])
                         .distinct
                         .pluck(:city)
                         .sort
                         .first(10)
                         .map { |name| { name: name, display_name: name } }

    render json: { cities: city_names }
  end

  # GET /plans/recommendations
  # Dohvati preporučena iskustva i planove za grad
  def recommendations
    city_name = params[:city_name]

    unless city_name.present?
      render json: { error: "City name required" }, status: :bad_request
      return
    end

    # Exclude experience IDs that are already in the user's plan
    exclude_ids = parse_exclude_ids(params[:exclude_ids])

    # Get recommended experiences from locations in the same city
    # Use subquery to get distinct IDs first, then apply random order
    distinct_exp_ids = Experience.joins(:locations)
                                 .where(locations: { city: city_name })
                                 .where.not(id: exclude_ids)
                                 .select("DISTINCT experiences.id")

    experiences = Experience.where("experiences.id IN (#{distinct_exp_ids.to_sql})")
                            .includes(:locations)
                            .order("RANDOM()")
                            .limit(4)
                            .map do |exp|
      {
        id: exp.uuid,
        title: exp.title,
        description: exp.description&.truncate(120),
        formatted_duration: exp.formatted_duration,
        locations_count: exp.locations.size
      }
    end

    # Get popular plans for the same city
    # Use includes to prevent N+1 queries when counting experiences
    plans = Plan.where(city_name: city_name)
                .visibility_public_plan
                .includes(:experiences)
                .popular
                .limit(4)
                .map do |plan|
      {
        id: plan.uuid,
        title: plan.title,
        duration_days: plan.duration_in_days,
        experiences_count: plan.experiences.size,
        average_rating: plan.average_rating,
        reviews_count: plan.reviews_count
      }
    end

    render json: {
      experiences: experiences,
      plans: plans,
      city_name: city_name
    }
  end

  # POST /plans/generate
  # Generiraj personalizirani plan bez spremanja u bazu
  def generate
    city_name = params[:city_name]
    unless city_name.present?
      render json: { error: I18n.t("plans.errors.city_not_found") }, status: :not_found
      return
    end

    # Parse and validate parameters with feedback
    duration = parse_duration(params[:duration])
    budget = validate_budget(params[:budget])
    meat_lover = params[:meat_lover] == "true" || params[:meat_lover] == true
    daily_hours = parse_daily_hours(params[:daily_hours])
    interests = parse_interests(params[:interests])

    # Collect validation warnings (non-fatal issues)
    warnings = []
    if params[:budget].present? && budget.nil?
      warnings << I18n.t("plans.errors.invalid_budget", default: "Invalid budget value, using default")
    end

    # Pronađi relevantne lokacije
    locations = find_matching_locations(city_name, budget, meat_lover, interests)

    if locations.empty?
      # Try without filters if no locations match
      locations = Location.where(city: city_name).order("RANDOM()").limit(20)
      if locations.any?
        warnings << I18n.t("plans.errors.no_matching_locations", default: "No locations matched your preferences, showing all available")
      end
    end

    # Pronađi experience-e koji sadrže te lokacije
    experiences = find_matching_experiences(locations)

    if experiences.empty?
      render json: {
        error: I18n.t("plans.errors.no_experiences_available", default: "No experiences available for this city"),
        city_name: city_name
      }, status: :unprocessable_entity
      return
    end

    # Generiraj plan strukturu
    plan_data = build_plan(city_name, duration, daily_hours, experiences, {
      budget: budget,
      meat_lover: meat_lover,
      daily_hours: daily_hours,
      interests: interests
    })

    # Include warnings in response if any
    plan_data[:warnings] = warnings if warnings.present?

    render json: plan_data
  end

  private

  def parse_exclude_ids(exclude_ids_param)
    return [] if exclude_ids_param.blank?

    uuids = if exclude_ids_param.is_a?(String)
      begin
        JSON.parse(exclude_ids_param)
      rescue JSON::ParserError
        exclude_ids_param.split(",").map(&:strip)
      end
    else
      exclude_ids_param.to_a
    end

    # Convert UUIDs to database IDs for the query
    Experience.where(uuid: uuids).pluck(:id)
  end

  def parse_duration(duration_param)
    case duration_param
    when "1"
      1
    when "2-3"
      2
    when "4+"
      4
    else
      2
    end
  end

  def parse_interests(interests_param)
    return [] if interests_param.blank?

    raw_interests = if interests_param.is_a?(String)
      begin
        JSON.parse(interests_param)
      rescue JSON::ParserError
        interests_param.split(",").map(&:strip)
      end
    else
      interests_param.to_a
    end

    # Security: Only allow valid interests from the supported list
    valid_keys = ExperienceType.active_keys
    raw_interests.map(&:to_s).map(&:downcase).select do |interest|
      valid_keys.include?(interest)
    end
  end

  def validate_budget(budget_param)
    return nil if budget_param.blank?

    # Only allow valid budget values
    budget = budget_param.to_s.downcase
    Location.budgets.key?(budget) ? budget : nil
  end

  def parse_daily_hours(daily_hours_param)
    return DEFAULT_DAILY_HOURS if daily_hours_param.blank?

    hours = daily_hours_param.to_i
    # Clamp to valid range
    hours.clamp(MIN_DAILY_HOURS, MAX_DAILY_HOURS)
  end

  def find_matching_locations(city_name, budget, meat_lover, interests)
    locations = Location.where(city: city_name)

    # Filter by budget (already validated by validate_budget)
    if budget.present?
      case budget
      when "low"
        locations = locations.where(budget: :low)
      when "medium"
        locations = locations.where(budget: [ :low, :medium ])
      # high budget = all locations (no filter)
      end
    end

    # Filter po meat preference
    if meat_lover
      # Uključi meat, food, isključi striktno vegetarian/vegan AKO nisu eksplicitno traženi
      unless interests.include?("vegan") || interests.include?("vegetarian")
        # PostgreSQL: check if JSONB array contains 'vegan'
        locations = locations.where.not("suitable_experiences @> ?", [ "vegan" ].to_json)
      end
    else
      # Non-meat lover - preferiraj vegan/vegetarian opcije za food
      # Ali ne isključuj ostale tipove lokacija
    end

    # Filter po interesima using PostgreSQL JSONB operators
    if interests.any?
      # Use JSONB ?| operator to check if array contains ANY of the interests
      locations = locations.where("suitable_experiences ?| array[:interests]", interests: interests)
    end

    locations.order("RANDOM()").limit(20)
  end

  def find_matching_experiences(locations)
    return Experience.none if locations.empty?

    location_ids = locations.pluck(:id)

    # Use subquery to get distinct IDs first, then random order
    distinct_ids_subquery = Experience.joins(:experience_locations)
                                      .where(experience_locations: { location_id: location_ids })
                                      .select("DISTINCT experiences.id")

    Experience.where("experiences.id IN (#{distinct_ids_subquery.to_sql})")
              .includes(:locations)
              .order("RANDOM()")
              .limit(10)
  end

  def build_plan(city_name, duration_days, daily_hours, experiences, preferences)
    experiences_array = experiences.to_a
    max_daily_minutes = daily_hours * 60

    # Step 1: Calculate total available time for the trip
    total_available_minutes = duration_days * max_daily_minutes

    # Step 2: Select experiences that fit within the available time
    selected_experiences = select_experiences_within_limit(experiences_array, total_available_minutes)

    # Step 3: Group selected experiences by geographic proximity
    grouped_experiences = group_by_proximity(selected_experiences)

    # Step 4: Distribute experiences across days respecting time limits
    days = distribute_experiences_to_days(grouped_experiences, duration_days, max_daily_minutes)

    # Step 5: Calculate statistics based on selected (not all) experiences
    total_minutes = selected_experiences.sum { |e| e.estimated_duration || DEFAULT_EXPERIENCE_DURATION }
    days_with_content = days.count { |d| d[:experiences].any? }
    avg_daily_minutes = days_with_content > 0 ? (total_minutes.to_f / days_with_content).round : 0

    {
      id: SecureRandom.uuid,
      generated_at: Time.current.iso8601,
      city_name: city_name,
      duration_days: duration_days,
      preferences: preferences,
      days: days,
      total_experiences: selected_experiences.size,
      statistics: {
        total_duration_minutes: total_minutes,
        total_duration_formatted: format_duration(total_minutes),
        average_daily_minutes: avg_daily_minutes,
        average_daily_formatted: format_duration(avg_daily_minutes),
        max_daily_limit: max_daily_minutes,
        experiences_per_day: days.map { |d| d[:experiences].size }
      },
      saved: false
    }
  end

  # Select experiences that fit within the available time budget
  def select_experiences_within_limit(experiences, total_available_minutes)
    selected = []
    remaining_time = total_available_minutes

    # Sort by duration (shorter first to maximize variety)
    sorted = experiences.sort_by { |e| e.estimated_duration || DEFAULT_EXPERIENCE_DURATION }

    sorted.each do |exp|
      duration = exp.estimated_duration || DEFAULT_EXPERIENCE_DURATION

      if remaining_time >= duration
        selected << exp
        remaining_time -= duration
      end
    end

    selected
  end

  # Group experiences by geographic proximity of their locations
  def group_by_proximity(experiences)
    return experiences if experiences.size <= 2

    # Calculate centroid for each experience (average of its location coordinates)
    experiences_with_centroids = experiences.map do |exp|
      coords = exp.locations.select(&:geocoded?).map(&:coordinates)
      centroid = if coords.any?
        [
          coords.sum { |c| c[0] } / coords.size,
          coords.sum { |c| c[1] } / coords.size
        ]
      end
      { experience: exp, centroid: centroid }
    end

    # Sort by centroid to keep nearby experiences together
    # Using a simple sort by latitude then longitude (works well for single-city plans)
    experiences_with_centroids.sort_by do |item|
      if item[:centroid]
        [ item[:centroid][0], item[:centroid][1] ]
      else
        [ 0, 0 ] # Put experiences without coordinates at the start
      end
    end.map { |item| item[:experience] }
  end

  # Distribute experiences across days respecting time limits
  def distribute_experiences_to_days(experiences, duration_days, max_daily_minutes)
    # Initialize day containers
    day_data = Array.new(duration_days) do |i|
      {
        day_number: i + 1,
        date: (Date.today + i).iso8601,
        experiences: [],
        total_minutes: 0
      }
    end

    # Sort experiences by duration (longer first - bin packing first-fit decreasing)
    sorted_experiences = experiences.sort_by do |exp|
      -(exp.estimated_duration || DEFAULT_EXPERIENCE_DURATION)
    end

    # Distribute experiences using first-fit decreasing algorithm
    sorted_experiences.each do |exp|
      duration = exp.estimated_duration || DEFAULT_EXPERIENCE_DURATION

      # Find the first day that can accommodate this experience
      target_day = day_data.find do |day|
        (day[:total_minutes] + duration) <= max_daily_minutes
      end

      # If no day can fit it within limits, find the day with least time
      target_day ||= day_data.min_by { |day| day[:total_minutes] }

      # Add experience to the day
      target_day[:experiences] << exp
      target_day[:total_minutes] += duration
    end

    # Convert to final format with experience details
    day_data.map do |day|
      {
        day_number: day[:day_number],
        date: day[:date],
        total_duration_minutes: day[:total_minutes],
        total_duration_formatted: format_duration(day[:total_minutes]),
        experiences: day[:experiences].map { |exp| serialize_experience(exp) }
      }
    end
  end

  # Serialize experience for JSON response
  def serialize_experience(exp)
    {
      id: exp.uuid,
      uuid: exp.uuid,
      title: exp.title,
      description: exp.description,
      estimated_duration: exp.estimated_duration || DEFAULT_EXPERIENCE_DURATION,
      formatted_duration: exp.formatted_duration || format_duration(DEFAULT_EXPERIENCE_DURATION),
      locations: exp.locations.map do |loc|
        {
          id: loc.uuid,
          uuid: loc.uuid,
          name: loc.name,
          description: loc.description,
          category: loc.category_key,
          categories: loc.category_keys,
          budget: loc.budget,
          lat: loc.lat,
          lng: loc.lng,
          city: loc.city,
          suitable_experiences: loc.suitable_experiences
        }
      end
    }
  end

  # Format minutes into human-readable duration
  def format_duration(minutes)
    return "0min" if minutes.nil? || minutes <= 0

    hours = minutes / 60
    mins = minutes % 60

    if hours > 0 && mins > 0
      "#{hours}h #{mins}min"
    elsif hours > 0
      "#{hours}h"
    else
      "#{mins}min"
    end
  end

  def redirect_to_explore
    redirect_to explore_path, alert: I18n.t("plans.not_found", default: "Plan not found. Explore other plans.")
  end
end

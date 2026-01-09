# Service for normalizing Location, Experience, and Plan data for the Browse model
# This adapter extracts only the fields needed for full-text search and filtering
class BrowseAdapter
  class << self
    # Generate attributes for a Browse record based on the source model
    def attributes_for(record)
      case record
      when Location
        location_attributes(record)
      when Experience
        experience_attributes(record)
      when Plan
        plan_attributes(record)
      else
        nil
      end
    end

    private

    def location_attributes(location)
      # Only sync places, not contacts
      return nil unless location.place_type?

      {
        title: location.name,
        description: build_location_description(location),
        browsable_subtype: location.category_key,  # Uses new category_key method
        city_name: location.city,
        lat: location.lat,
        lng: location.lng,
        average_rating: location.average_rating,
        reviews_count: location.reviews_count,
        budget: location.budget_before_type_cast,
        category_keys: location.category_keys,
        seasons: location.seasons,
        ai_generated: location.ai_generated
      }
    end

    def experience_attributes(experience)
      # Get city from first location
      first_location = experience.locations.first

      {
        title: experience.title,
        description: build_experience_description(experience),
        browsable_subtype: experience.category_key,
        city_name: first_location&.city,
        lat: first_location&.lat,
        lng: first_location&.lng,
        average_rating: experience.average_rating,
        reviews_count: experience.reviews_count,
        budget: nil, # Experiences don't have budget
        category_keys: [ experience.category_key ].compact,
        seasons: experience.seasons,
        ai_generated: experience.ai_generated
      }
    end

    def plan_attributes(plan)
      # Only sync public plans
      return nil unless plan.visibility_public_plan?

      # Get coordinates from the plan's first experience location
      first_location = plan.experiences.flat_map(&:locations).first

      # Aggregate seasons from all experiences in the plan
      plan_seasons = plan.experiences.flat_map(&:seasons).uniq

      {
        title: plan.title,
        description: build_plan_description(plan),
        browsable_subtype: nil, # Plans don't have subtypes
        city_name: plan.city_name,
        lat: first_location&.lat,
        lng: first_location&.lng,
        average_rating: plan.average_rating,
        reviews_count: plan.reviews_count,
        budget: nil, # Plans don't have budget
        category_keys: [],
        seasons: plan_seasons,
        ai_generated: plan.ai_generated
      }
    end

    # Build searchable description for location
    # Combines description, historical context, tags, category name, and city name
    def build_location_description(location)
      parts = []
      parts << location.description if location.description.present?
      parts << location.historical_context if location.historical_context.present?
      parts << location.category_name if location.category_name.present?
      parts << location.tags.join(" ") if location.tags.present?
      parts << location.city if location.city.present?
      parts.join(" ")
    end

    # Build searchable description for experience
    # Combines description, category name, and location names
    def build_experience_description(experience)
      parts = []
      parts << experience.description if experience.description.present?
      parts << experience.category_name if experience.category_name.present?

      # Include location names for searchability
      location_names = experience.locations.pluck(:name).join(" ")
      parts << location_names if location_names.present?

      # Include city name from first location
      city_name = experience.locations.first&.city
      parts << city_name if city_name.present?

      parts.join(" ")
    end

    # Build searchable description for plan
    # Combines notes, city name, and experience titles
    def build_plan_description(plan)
      parts = []
      parts << plan.notes if plan.notes.present?
      parts << plan.city_name if plan.city_name.present?

      # Include experience titles for searchability
      experience_titles = plan.experiences.pluck(:title).join(" ")
      parts << experience_titles if experience_titles.present?

      parts.join(" ")
    end
  end
end

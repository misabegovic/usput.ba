# frozen_string_literal: true

module Usput
  module Commands
    # How records read outside a page: public ids, names in the asked
    # language, no database ids.
    module Serialize
      module_function

      def place(location)
        { id: location.uuid, name: location.name, city: location.city, category: location.category_key,
          lat: location.lat&.to_f, lng: location.lng&.to_f, rating: location.average_rating&.to_f,
          reviews: location.reviews_count, accessible: location.wheelchair_accessible?,
          archived: location.archived? }
      end

      def experience(experience)
        { id: experience.uuid, title: experience.title, category: experience.category_key,
          minutes: experience.estimated_duration, places: experience.locations.size,
          rating: experience.average_rating&.to_f }
      end

      def plan(plan)
        { id: plan.uuid, title: plan.display_title, city: plan.city_name, days: plan.duration_in_days,
          public: plan.visibility_public_plan?, rating: plan.average_rating&.to_f }
      end

      def moment(moment)
        { id: moment.uuid, place: moment.location.name, city: moment.location.city, note: moment.note,
          by: moment.user.username, status: moment.moderation_status, taken_at: moment.created_at.iso8601 }
      end

      def review(review)
        { id: review.uuid, on: "#{review.reviewable_type} #{review.reviewable.uuid}", rating: review.rating,
          comment: review.comment, by: review.user&.username, status: review.moderation_status,
          jev_band: review.jev_band, jev_answers: review.jev_answers.presence, written_at: review.created_at.iso8601 }
      end
    end
  end
end

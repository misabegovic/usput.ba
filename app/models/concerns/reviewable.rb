# frozen_string_literal: true

module Reviewable
  extend ActiveSupport::Concern

  included do
    has_many :reviews, as: :reviewable, dependent: :destroy

    scope :popular, -> { order(average_rating: :desc, reviews_count: :desc) }
    scope :most_reviewed, -> { order(reviews_count: :desc) }
    scope :top_rated, -> { where("reviews_count > 0").order(average_rating: :desc) }

    # Trending: items with recent reviews (last 30 days) sorted by recent activity and rating
    scope :trending, ->(days: 30) {
      recent_date = days.days.ago

      joins(:reviews)
        .where("reviews.created_at >= ?", recent_date)
        .group("#{table_name}.id")
        .select(
          "#{table_name}.*",
          "COUNT(reviews.id) as recent_reviews_count",
          "AVG(reviews.rating) as recent_average_rating"
        )
        .order("recent_reviews_count DESC, recent_average_rating DESC")
    }

    # Trending with fallback to popular if no recent reviews
    scope :trending_or_popular, ->(days: 30) {
      trending_items = trending(days: days)
      trending_items.any? ? trending_items : popular
    }
  end

  def rating_percentage
    return 0 if average_rating.nil? || average_rating.zero?
    (average_rating / 5.0 * 100).round
  end

  def rating_stars
    return [] unless average_rating

    full_stars = average_rating.floor
    has_half = (average_rating - full_stars) >= 0.5
    empty_stars = 5 - full_stars - (has_half ? 1 : 0)

    stars = []
    full_stars.times { stars << :full }
    stars << :half if has_half
    empty_stars.times { stars << :empty }
    stars
  end

  def has_reviews?
    reviews_count.to_i > 0
  end
end

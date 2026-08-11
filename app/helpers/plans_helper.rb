# frozen_string_literal: true

module PlansHelper
  def interest_icon(interest)
    icons = {
      "culture" => "🎭",
      "history" => "🏛️",
      "sport" => "⚽",
      "vegan" => "🌱",
      "vegetarian" => "🥬",
      "meat" => "🥩",
      "food" => "🍽️",
      "nature" => "🌿",
      "woods" => "🌲",
      "mountains" => "⛰️"
    }
    icons[interest.to_s] || "📍"
  end

  def interest_label(interest)
    I18n.t("wizard.interests.#{interest}", default: interest.to_s.humanize)
  end

  def budget_label(budget)
    I18n.t("locations.budget.#{budget}", default: budget.to_s.humanize)
  end

  # location_type_label lives in ApplicationHelper (shared across all views) and
  # guards against a blank key rendering the whole locations.types hash.

  def formatted_duration(minutes)
    return nil unless minutes

    hours = minutes / 60
    mins = minutes % 60

    if hours > 0 && mins > 0
      "#{I18n.t('experiences.duration.hours', count: hours)} #{I18n.t('experiences.duration.minutes', count: mins)}"
    elsif hours > 0
      I18n.t("experiences.duration.hours", count: hours)
    else
      I18n.t("experiences.duration.minutes", count: mins)
    end
  end

  def day_label(day_number)
    I18n.t("plans.show.day", number: day_number)
  end
end

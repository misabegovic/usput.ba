# frozen_string_literal: true

# KnowledgeSummary - AI-generated summaries za Knowledge Layer 1
#
# Čuva AI-generisane summary-je po dimenzijama (region, category, city).
# Svaki summary uključuje:
# - Tekstualni opis stanja
# - Statistike
# - Identifikovane probleme
# - Prepoznate pattern-e
#
# Primjer:
#   summary = KnowledgeSummary.for_dimension(:city, "Mostar")
#   summary.summary # => "Mostar je turistički centar Hercegovine..."
#   summary.issues  # => [{ type: "missing_audio", count: 24 }]
#
class KnowledgeSummary < ApplicationRecord
  # Dozvoljene dimenzije
  DIMENSIONS = %w[city region category].freeze

  # Validacije
  validates :dimension, presence: true, inclusion: { in: DIMENSIONS }
  validates :dimension_value, presence: true
  validates :dimension, uniqueness: { scope: :dimension_value }

  # Scopes
  scope :for_dimension, ->(dim) { where(dimension: dim.to_s) }
  scope :fresh, ->(max_age = 1.hour) { where("generated_at > ?", max_age.ago) }
  scope :stale, ->(max_age = 1.hour) { where("generated_at <= ? OR generated_at IS NULL", max_age.ago) }
  scope :recent, -> { order(generated_at: :desc) }

  class << self
    # Dohvati summary za određenu dimenziju i vrijednost
    def for_dimension_value(dimension, value)
      find_by(dimension: dimension.to_s, dimension_value: value.to_s)
    end

    # Dohvati sve summary-je za dimenziju
    def list_for_dimension(dimension)
      for_dimension(dimension).order(:dimension_value)
    end

    # Dohvati sve dostupne dimenzije i njihove vrijednosti
    def available_dimensions
      DIMENSIONS.each_with_object({}) do |dim, hash|
        hash[dim] = where(dimension: dim).pluck(:dimension_value).sort
      end
    end

    # Dohvati summary-je sa issues
    def with_issues
      where("jsonb_array_length(issues) > 0")
    end

    # Vrati listu svih gradova koji imaju summary
    def cities
      for_dimension(:city).pluck(:dimension_value).sort
    end

    # Vrati listu svih kategorija koji imaju summary
    def categories
      for_dimension(:category).pluck(:dimension_value).sort
    end
  end

  # Instance metode

  # Da li je summary fresh?
  def fresh?(max_age = 1.hour)
    generated_at.present? && generated_at > max_age.ago
  end

  # Da li je summary stale?
  def stale?(max_age = 1.hour)
    !fresh?(max_age)
  end

  # Ima li issues?
  def has_issues?
    issues.present? && issues.any?
  end

  # Broj issues-a
  def issues_count
    issues&.size || 0
  end

  # Formatirani prikaz za CLI
  def to_cli_format
    output = []
    output << "=== #{dimension.titleize}: #{dimension_value} ==="
    output << ""
    output << summary if summary.present?
    output << ""

    if stats.present?
      output << "### Statistike"
      format_hash(stats).each { |line| output << "  #{line}" }
      output << ""
    end

    if has_issues?
      output << "### Problemi (#{issues_count})"
      issues.each do |issue|
        issue = issue.with_indifferent_access
        output << "  - #{issue[:type]}: #{issue[:count] || issue[:message]}"
      end
      output << ""
    end

    if patterns.present? && patterns.any?
      output << "### Patterns"
      patterns.each { |p| output << "  - #{p}" }
      output << ""
    end

    output << "Generated: #{generated_at&.strftime('%Y-%m-%d %H:%M')}"
    output << "Sources: #{source_count} records"

    output.join("\n")
  end

  # Kratki pregled za listu
  def to_short_format
    issue_badge = has_issues? ? " [#{issues_count} issues]" : ""
    "#{dimension_value} (#{source_count} records)#{issue_badge}"
  end

  private

  def format_hash(hash, indent = 0)
    lines = []
    hash.each do |key, value|
      prefix = "  " * indent
      if value.is_a?(Hash)
        lines << "#{prefix}#{key}:"
        lines.concat(format_hash(value, indent + 1))
      else
        lines << "#{prefix}#{key}: #{value}"
      end
    end
    lines
  end
end

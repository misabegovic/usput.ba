# frozen_string_literal: true

# Tracks individual curator contributions to a content change proposal.
# Multiple curators can contribute to the same proposal.
class ContentChangeContribution < ApplicationRecord
  belongs_to :content_change
  belongs_to :user

  validates :proposed_data, presence: true, unless: -> { proposed_data == {} }
  validates :user_id, uniqueness: { scope: :content_change_id, message: "already contributed to this proposal" }

  # Sanitize the proposed data to prevent XSS
  before_save :sanitize_proposed_data

  private

  def sanitize_proposed_data
    return if proposed_data.blank?

    self.proposed_data = proposed_data.transform_values do |value|
      case value
      when String
        ActionController::Base.helpers.sanitize(value, tags: %w[b i em strong br p], attributes: [])
      when Array
        value.map { |v| v.is_a?(String) ? ActionController::Base.helpers.sanitize(v, tags: [], attributes: []) : v }
      else
        value
      end
    end
  end
end

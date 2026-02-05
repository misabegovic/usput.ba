# frozen_string_literal: true

# PlanSuggestion - Per-resource suggestion model for plans
#
# Replaces ContentChange for plan-specific suggestions with typed columns
# and Active Storage support. Supports multi-curator contributions through
# PlanSuggestionContribution model.
#
# One pending suggestion per plan enforced by unique constraint.
# Multiple curators can contribute to the same suggestion.
#
# Usage:
#   # Create or find pending suggestion
#   suggestion = PlanSuggestion.find_or_create_pending!(
#     plan,
#     user: current_user,
#     origin: :human,
#     change_type: :update_resource
#   )
#
#   # Update with proposed changes
#   suggestion.update!(
#     proposed_title: "3 Days in Sarajevo",
#     proposed_city_name: "Sarajevo",
#     proposed_experience_days: { "1" => ["uuid1", "uuid2"], "2" => ["uuid3"] }
#   )
#
#   # Add cover photo
#   suggestion.proposed_cover_photo.attach(params[:cover_photo])
#
#   # Approve (applies changes to plan)
#   suggestion.approve!(admin_user)
#
class PlanSuggestion < ApplicationRecord
  include Suggestable

  belongs_to :plan, optional: true  # nil for create_resource
  has_many :contributions, class_name: "PlanSuggestionContribution", dependent: :destroy
  has_one_attached :proposed_cover_photo

  # Returns the resource association column name for Suggestable concern
  def self.resource_association_column
    :plan_id
  end

  # Apply proposed changes to the plan
  # Creates new plan for create_resource, updates for update_resource, deletes for delete_resource
  def apply_changes!
    case change_type
    when "create_resource"
      attrs = proposed_attributes
      new_plan = Plan.create!(attrs)
      update_plan_experiences!(new_plan) if proposed_experience_days.present?
      attach_cover_photo!(new_plan) if proposed_cover_photo.attached?
      update!(plan: new_plan)
    when "update_resource"
      attrs = proposed_attributes
      self.plan.update!(attrs)
      update_plan_experiences!(self.plan) if proposed_experience_days.present?
      attach_cover_photo!(self.plan) if proposed_cover_photo.attached?
    when "delete_resource"
      self.plan.destroy!
    end
  end

  private

  # Build hash of proposed attributes from typed columns
  def proposed_attributes
    attrs = {}
    attrs[:title] = proposed_title if proposed_title.present?
    attrs[:notes] = proposed_notes if proposed_notes.present?
    attrs[:city_name] = proposed_city_name if proposed_city_name.present?
    attrs[:start_date] = proposed_start_date if proposed_start_date.present?
    attrs[:end_date] = proposed_end_date if proposed_end_date.present?
    attrs[:visibility] = proposed_visibility if proposed_visibility.present?
    attrs[:preferences] = proposed_preferences if proposed_preferences.present?
    attrs
  end

  # Update plan experiences using the experience_days setter
  def update_plan_experiences!(plan)
    plan.experience_days = proposed_experience_days
  end

  # Attach proposed cover photo to the plan (if plan supports it)
  def attach_cover_photo!(plan)
    plan.cover_photo.attach(proposed_cover_photo.blob) if plan.respond_to?(:cover_photo)
  end
end

# frozen_string_literal: true

# PreparedPrompt - Stores prepared prompts for fixes and features
#
# Platform generates these prompts when it detects issues or receives
# requests for features. They can be reviewed and applied later.
#
# @example Prompt types
#   - fix: Bug fixes, performance issues, N+1 queries
#   - feature: New functionality requests
#   - improvement: Code quality, refactoring
#   - documentation: Missing or outdated docs
#
# @example Severity levels
#   - critical: Security issues, data loss risks
#   - high: Performance issues, broken features
#   - medium: Bugs affecting user experience
#   - low: Minor issues, nice-to-haves
#
class PreparedPrompt < ApplicationRecord
  belongs_to :user, optional: true

  # Prompt types
  enum :prompt_type, {
    fix: "fix",
    feature: "feature",
    improvement: "improvement",
    documentation: "documentation"
  }, prefix: true

  # Status workflow
  enum :status, {
    pending: "pending",
    in_progress: "in_progress",
    applied: "applied",
    rejected: "rejected"
  }, prefix: true

  # Severity levels
  enum :severity, {
    critical: "critical",
    high: "high",
    medium: "medium",
    low: "low"
  }, prefix: true

  # Validations
  validates :prompt_type, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true

  # Scopes
  scope :pending, -> { status_pending }
  scope :by_severity, -> { order(Arel.sql("CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 ELSE 4 END")) }
  scope :recent, -> { order(created_at: :desc) }
  scope :fixes, -> { prompt_type_fix }
  scope :features, -> { prompt_type_feature }

  # Mark as in progress
  def start!
    update!(status: :in_progress)
  end

  # Mark as applied
  def apply!(notes: nil)
    update!(
      status: :applied,
      metadata: metadata.merge(
        applied_at: Time.current.iso8601,
        apply_notes: notes
      )
    )
  end

  # Mark as rejected
  def reject!(reason:)
    update!(
      status: :rejected,
      metadata: metadata.merge(
        rejected_at: Time.current.iso8601,
        rejection_reason: reason
      )
    )
  end

  # Generate a full prompt for Claude Code
  def to_claude_prompt
    prompt = <<~PROMPT
      # #{title}

      ## Type: #{prompt_type.titleize}
      #{severity ? "## Severity: #{severity.titleize}" : ""}
      #{target_file ? "## Target File: #{target_file}" : ""}

      ## Problem Description
      #{content}

      #{analysis.present? ? "## Analysis\n#{analysis}" : ""}

      #{solution.present? ? "## Proposed Solution\n#{solution}" : ""}

      #{metadata["context"].present? ? "## Additional Context\n#{metadata['context']}" : ""}
    PROMPT

    prompt.strip
  end

  # Format for display
  def to_short_format
    {
      id: id,
      type: prompt_type,
      severity: severity,
      title: title,
      status: status,
      target_file: target_file,
      created_at: created_at.iso8601
    }
  end

  # Format with full details
  def to_full_format
    {
      id: id,
      type: prompt_type,
      severity: severity,
      title: title,
      status: status,
      content: content,
      analysis: analysis,
      solution: solution,
      target_file: target_file,
      metadata: metadata,
      created_at: created_at.iso8601,
      claude_prompt: to_claude_prompt
    }
  end
end

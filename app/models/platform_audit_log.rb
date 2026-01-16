# frozen_string_literal: true

# PlatformAuditLog - Audit trail for Platform mutations
#
# Records all create, update, and delete operations performed through
# the Platform DSL for accountability and debugging.
#
# @example Log a create operation
#   PlatformAuditLog.log_create(location, triggered_by: "platform_cli")
#
# @example Log an update operation
#   PlatformAuditLog.log_update(location, changes: { description: ["old", "new"] })
#
class PlatformAuditLog < PlatformRecord
  # Validations
  validates :action, presence: true, inclusion: { in: %w[create update delete approve reject] }
  validates :triggered_by, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_record, ->(type, id) { where(record_type: type, record_id: id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :creates, -> { by_action("create") }
  scope :updates, -> { by_action("update") }
  scope :deletes, -> { by_action("delete") }
  scope :approvals, -> { by_action("approve") }
  scope :rejections, -> { by_action("reject") }
  scope :for_conversation, ->(conv_id) { where(conversation_id: conv_id) }

  class << self
    # Log a create operation
    #
    # @param record [ActiveRecord::Base] The created record
    # @param triggered_by [String] Who triggered the action (e.g., "platform_cli", "platform_api")
    # @param conversation_id [String, nil] Optional conversation UUID
    # @return [PlatformAuditLog]
    def log_create(record, triggered_by:, conversation_id: nil)
      create!(
        action: "create",
        record_type: record.class.name,
        record_id: record.id,
        change_data: { attributes: record.attributes.except("created_at", "updated_at") },
        triggered_by: triggered_by,
        conversation_id: conversation_id
      )
    end

    # Log an update operation
    #
    # @param record [ActiveRecord::Base] The updated record
    # @param changes [Hash] The changes made (from saved_changes or similar)
    # @param triggered_by [String] Who triggered the action
    # @param conversation_id [String, nil] Optional conversation UUID
    # @return [PlatformAuditLog]
    def log_update(record, changes:, triggered_by:, conversation_id: nil)
      create!(
        action: "update",
        record_type: record.class.name,
        record_id: record.id,
        change_data: { changes: changes },
        triggered_by: triggered_by,
        conversation_id: conversation_id
      )
    end

    # Log a delete operation
    #
    # @param record [ActiveRecord::Base] The deleted record
    # @param triggered_by [String] Who triggered the action
    # @param conversation_id [String, nil] Optional conversation UUID
    # @return [PlatformAuditLog]
    def log_delete(record, triggered_by:, conversation_id: nil)
      create!(
        action: "delete",
        record_type: record.class.name,
        record_id: record.id,
        change_data: { deleted_attributes: record.attributes },
        triggered_by: triggered_by,
        conversation_id: conversation_id
      )
    end
  end

  # Human-readable summary
  def summary
    case action
    when "create"
      "Created #{record_type} ##{record_id}"
    when "update"
      fields = change_data["changes"]&.keys&.join(", ") || "unknown fields"
      "Updated #{record_type} ##{record_id} (#{fields})"
    when "delete"
      "Deleted #{record_type} ##{record_id}"
    end
  end
end

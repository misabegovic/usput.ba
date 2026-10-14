# Avo uploads and deletes a record's files (a place's photos, a tour's audio,
# a user's avatar) through its own attachments controller, which the
# per-resource gate does not reach and whose own check allows everything in
# Avo Community. Changing a record's files counts as editing the record, so
# the record's policy decides: a curator may change a place's photos but not
# a user's avatar or a traveller's moment.
module AdminAttachmentGate
  extend ActiveSupport::Concern

  included do
    before_action :enforce_record_policy, only: %i[create destroy]
  end

  private

  def enforce_record_policy
    raise Avo::NotAuthorizedError unless AdminPolicy.for(@resource.model_class).new(_current_user, @record).update?
  end
end

# Avo attaches and detaches related records (a plan's experiences, an
# experience's places) through its own associations controller. Linking or
# unlinking counts as editing the parent, so the parent's policy decides.
module AdminAssociationGate
  extend ActiveSupport::Concern

  included do
    before_action :enforce_parent_policy
  end

  private

  def enforce_parent_policy
    policy = AdminPolicy.for(@resource.model_class).new(_current_user, @record)
    allowed = action_name.in?(%w[index show]) ? policy.show? : policy.update?
    raise Avo::NotAuthorizedError unless allowed
  end
end

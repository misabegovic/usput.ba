# Every Avo resource controller asks the resource's policy before each request,
# after Avo has loaded the record, and refuses what the policy does not allow.
module AdminPolicyGate
  extend ActiveSupport::Concern

  included do
    before_action :enforce_admin_policy
  end

  private

  def enforce_admin_policy
    policy = AdminPolicy.for(@resource.model_class).new(_current_user, @record)
    raise Avo::NotAuthorizedError unless policy.allows?(action_name)
  end
end

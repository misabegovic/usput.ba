# What every Avo resource controller shares. The resource's policy is asked
# before each request, after Avo has loaded the record, and whatever the policy
# does not allow is refused. The signed-in user is recorded as the editor, so
# models can tell a person's change in the admin from the AI pipeline's.
module AdminResource
  extend ActiveSupport::Concern

  included do
    # Prepended, because Avo copies the form onto the record in a before_action
    # of its own, and the models need to know the editor while that happens.
    prepend_before_action { Current.editor = _current_user }
    before_action :enforce_admin_policy
  end

  private

  def enforce_admin_policy
    policy = AdminPolicy.for(@resource.model_class).new(_current_user, @record)
    raise Avo::NotAuthorizedError unless policy.allows?(action_name)
  end
end

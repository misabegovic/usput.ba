# Avo's searchable fields ask its search controller, which the per-resource
# gate does not reach. Searching a resource is listing it, so the resource's
# policy decides: a curator searching users (by name or email) is refused.
module AdminSearchGate
  extend ActiveSupport::Concern

  included do
    before_action :enforce_index_policy, only: :show
  end

  private

  def enforce_index_policy
    raise Avo::NotAuthorizedError unless AdminPolicy.for(@resource.model_class).new(_current_user).index?
  end
end

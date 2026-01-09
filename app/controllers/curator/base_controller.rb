module Curator
  class BaseController < ApplicationController
    before_action :require_login
    before_action :require_curator
    before_action :check_spam_block

    layout "curator"

    private

    def check_spam_block
      return unless current_user.spam_blocked?

      flash[:alert] = t("curator.spam_blocked", until: current_user.spam_blocked_until.strftime("%d.%m.%Y %H:%M"))
      redirect_to root_path
    end

    # Helper to record curator activities
    def record_activity(action, recordable: nil, metadata: {})
      CuratorActivity.record(
        user: current_user,
        action: action,
        recordable: recordable,
        metadata: metadata,
        request: request
      )

      # Increment activity count and check for spam
      current_user.increment_activity_count!
      current_user.check_spam_activity!
    end

    # Find pending proposal for a resource (for display on show/edit pages)
    def pending_proposal_for(resource)
      return nil unless resource.present?

      ContentChange.pending.find_by(
        changeable_type: resource.class.name,
        changeable_id: resource.id
      )
    end
    helper_method :pending_proposal_for
  end
end

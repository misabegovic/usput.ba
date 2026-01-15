# frozen_string_literal: true

module Curator
  module Admin
    # Base controller for admin features within curator dashboard.
    # Requires admin role in addition to curator role.
    class BaseController < Curator::BaseController
      before_action :require_admin
    end
  end
end

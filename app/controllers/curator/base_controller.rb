module Curator
  class BaseController < ApplicationController
    before_action :require_login
    before_action :require_curator

    layout "curator"
  end
end

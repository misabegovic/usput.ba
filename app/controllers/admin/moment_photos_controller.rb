# Serves a public moment's photo to the admin. Avo's own file field would hand
# out a signed blob url, which works for anyone holding it; this streams the
# bytes behind the same curator gate as the rest of the admin.
class Admin::MomentPhotosController < ApplicationController
  include ServesMomentPhotos

  before_action :require_login
  before_action :require_curator

  def show
    stream_moment_photo(MomentPolicy.visible(Moment).find_by_public_id!(params[:id]), public: false)
  end
end

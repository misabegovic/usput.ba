# frozen_string_literal: true

class Moments::LikesController < ApplicationController
  before_action :require_login
  before_action :set_moment

  def create
    current_user.likes.create(likeable: @moment)
    render_heart
  end

  def destroy
    current_user.likes.find_by(likeable: @moment)&.destroy
    render_heart
  end

  private


  # Through the scope, so a private moment is indistinguishable from a missing one.
  def set_moment
    @moment = Moment.publicly_visible.find_by_public_id!(params[:moment_id])
  end

  # Where it was tapped decides what is rewritten; a caption names its gallery.
  def render_heart
    @moment.reload

    respond_to do |format|
      format.turbo_stream { render turbo_stream: heart_stream }
      format.html { redirect_back fallback_location: explore_path }
    end
  end

  def heart_stream
    scope = params[:context].presence || "moments"

    [ tile_stream(scope),
      turbo_stream.replace("#{scope}_moment_like",
                           partial: "shared/moment_like",
                           locals: { moment: @moment, scope: scope }) ]
  end

  # The whole tile, not just its heart: the viewer reads the tile's data
  # attributes, so anything less leaves the two disagreeing.
  def tile_stream(scope)
    if scope == "location"
      turbo_stream.replace("location_#{helpers.dom_id(@moment)}",
                           partial: "plans/moment_gallery_item",
                           locals: { moment: @moment, context: params[:gallery_context],
                                     tile: params[:gallery_context].in?(%w[explore walk]) ?
                                       { wrapper: "text-center", image: "aspect-square w-full", size: "thumb", fill: [ 200, 200 ], inline_controls: true } :
                                       { wrapper: "flex-shrink-0 snap-start w-48 sm:w-56", image: "h-36 sm:h-40 w-full", size: "square", fill: [ 400, 300 ] } })
    elsif scope == "my_moments"
      turbo_stream.replace(helpers.dom_id(@moment),
                           partial: "new_design/explore/my_moment_card",
                           locals: { moment: @moment })
    elsif scope == "profile"
      turbo_stream.replace(helpers.dom_id(@moment),
                           partial: "travel_profiles/my_moment_tile",
                           locals: { moment: @moment })
    else
      turbo_stream.replace(helpers.dom_id(@moment, :public),
                           partial: "new_design/explore/moment_card",
                           locals: { moment: @moment, expandable: true })
    end
  end
end

# frozen_string_literal: true

class MomentsController < ApplicationController
  include ServesMomentPhotos

  # Surfaces that draw a moment as its own tile in a grid: the answer rewrites or
  # removes that tile. Everywhere else the moment lives inside a place's strip,
  # which is redrawn whole.
  TILE_CONTEXTS = %w[browse caption profile my_moments].freeze

  before_action :require_login, except: :index
  before_action :set_plan

  def index
    @location = Location.find_by_public_id!(params[:location_id])
    # Reached without a plan (a place browsed outside one): a signed-in traveller
    # still needs somewhere to upload to, and that is their explore plan. A guest
    # gets no plan and the form renders as a sign-in link.
    @plan ||= Plan.explore_bosnia_for(current_user) if logged_in?
    @page = [ (params[:moments_page] || params[:page]).to_i, 1 ].max
    @moments = if logged_in?
      current_user.moments.where(location: @location)
                  .with_attached_photo.includes(:plan).newest_first.page(@page).per(Moment::PAGE_SIZE)
    else
      Moment.none.page(1)
    end
    # Yours are already in @moments, private and public alike. Leaving them out
    # here keeps the two lists disjoint, so the counts that add them are right and
    # a page arrives full instead of losing rows the gallery would drop anyway.
    @public_moments = Moment.where(location: @location)
                            .with_attached_photo.includes(:user)
                            .publicly_visible.not_by(current_user)
                            .newest_first.page(@page).per(Moment::PAGE_SIZE)

    return render partial: "plans/moment_gallery_items",
                  locals: gallery_locals, layout: false if params[:partial] == "moments"

    render layout: false
  end

  def create
    @moment = current_user.moments.build(moment_params.merge(photo: CameraPhoto.as_jpeg(params.dig(:moment, :photo))))
    @moment.plan = @plan
    @moment.location = Location.find_by_public_id!(params[:moment][:location_id])

    respond_to do |format|
      if @moment.save
        format.html { redirect_back fallback_location: plan_path(@plan), notice: t("flash.moment.created") }
        format.turbo_stream { render :update, locals: { location: @moment.location } }
      else
        format.html { redirect_back fallback_location: plan_path(@plan), alert: @moment.errors.full_messages.join(", ") }
        format.turbo_stream do
          render :update, locals: { location: @moment.location, alert: @moment.errors.full_messages.join(", ") }
        end
      end
    end
  end

  def photo
    moment = current_user.moments.find_by_public_id!(params[:id])
    stream_moment_photo(moment, public: false)
  end

  # Edited in the viewer, which reads the tile — so the answer is the tile,
  # plus a line saying it landed.
  def update
    moment = current_user.moments.find_by_public_id!(params[:id])
    saved = moment.update(note: params.require(:moment).permit(:note)[:note])
    scope = params[:scope].presence || "my_moments"

    render turbo_stream: [
      turbo_stream.replace(helpers.dom_id(moment),
                           partial: "new_design/explore/my_moment_card",
                           locals: { moment: moment }),
      turbo_stream.replace("#{scope}_moment_status",
                           partial: "shared/moment_status",
                           locals: { scope: scope,
                                     message: t(saved ? "plans.moments.note_saved"
                                                      : "plans.moments.note_failed") })
    ]
  end

  def publish
    moment = current_user.moments.find_by_public_id!(params[:id])
    moment.update!(visibility: :public_moment)
    respond_with_visibility(moment, t("flash.moment.published"))
  end

  def unpublish
    moment = current_user.moments.find_by_public_id!(params[:id])
    moment.update!(visibility: :private_moment)
    respond_with_visibility(moment, t("flash.moment.unpublished"))
  end

  def destroy
    moment = current_user.moments.find_by_public_id!(params[:id])
    location = moment.location
    card = helpers.dom_id(moment)
    moment.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: plan_path(@plan), notice: t("flash.moment.destroyed") }
      format.turbo_stream do
        if TILE_CONTEXTS.include?(params[:context])
          render turbo_stream: turbo_stream.remove(card)
        else
          render :update, locals: { location: location }
        end
      end
    end
  end

  private

  # The panel and its load-more both render the same tiles from the same shape.
  def gallery_locals
    narrow = params[:context].in?(%w[explore walk])
    { moments: @moments, public_moments: @public_moments, context: params[:context],
      tile: narrow ? { wrapper: "text-center", image: "aspect-square w-full", size: "thumb", fill: [ 200, 200 ], inline_controls: true }
                   : { wrapper: "flex-shrink-0 snap-start w-48 sm:w-56", image: "h-36 sm:h-40 w-full", size: "square", fill: [ 400, 300 ] } }
  end

  def respond_with_visibility(moment, notice)
    respond_to do |format|
      format.turbo_stream { render_visibility_change(moment) }
      format.html { redirect_back fallback_location: plan_path(@plan), notice: notice }
    end
  end

  # Where the button was tapped decides what is rewritten: the walk and the reel
  # redraw the location's whole moment strip, the two grids redraw the one tile.
  # An absent context is the strip, not a reload: the gallery drops the param
  # when its frame was loaded without one, and reloading mid-walk to publish a
  # photo loses the traveller's place in the deck.
  # "caption" rewrites the same tile as "browse": the caption reads that tile.
  def render_visibility_change(moment)
    case params[:context]
    when "browse", "caption", "my_moments"
      render turbo_stream: turbo_stream.replace(helpers.dom_id(moment),
                                                partial: "new_design/explore/my_moment_card",
                                                locals: { moment: moment })
    when "profile"
      render turbo_stream: turbo_stream.replace(helpers.dom_id(moment),
                                                partial: "travel_profiles/my_moment_tile",
                                                locals: { moment: moment })
    else
      render :update, locals: { location: moment.location }
    end
  end

  # The location-nested index carries no plan_id: reading a place's moments is
  # not plan-scoped, and a guest in explore mode has no plan to name. Every
  # writing action is routed under a plan, and still demands one here.
  def set_plan
    return if params[:plan_id].blank? && action_name == "index"

    @plan = Plan.find_by_public_id!(params[:plan_id])

    unless @plan.visibility_public_plan? || @plan.user_id == current_user&.id
      raise ActiveRecord::RecordNotFound
    end
  end

  def moment_params
    params.require(:moment).permit(:photo, :note)
  end
end

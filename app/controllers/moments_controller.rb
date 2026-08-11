# frozen_string_literal: true

class MomentsController < ApplicationController
  include ServesMomentPhotos

  before_action :require_login, except: :index
  before_action :set_plan

  def index
    @location = Location.find_by_public_id!(params[:location_id])
    # Reached without a plan (a place browsed outside one): a signed-in traveller
    # still needs somewhere to upload to, and that is their explore plan. A guest
    # gets no plan and the form renders as a sign-in link.
    @plan ||= Plan.explore_bosnia_for(current_user) if logged_in?
    @moments = if logged_in?
      current_user.moments.where(location: @location).with_attached_photo.includes(:plan).recent_own
    else
      Moment.none
    end
    @public_moments = Moment.where(location: @location)
                            .with_attached_photo.recent_public

    render layout: false
  end

  def create
    @moment = current_user.moments.build(moment_params)
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
        if params[:context] == "browse"
          render turbo_stream: turbo_stream.remove(card)
        else
          render :update, locals: { location: location }
        end
      end
    end
  end

  private

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
  def render_visibility_change(moment)
    case params[:context]
    when "browse"
      render turbo_stream: turbo_stream.replace(helpers.dom_id(moment),
                                                partial: "new_design/explore/my_moment_card",
                                                locals: { moment: moment, index: params[:index].to_i })
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
    params.require(:moment).permit(:photo, :note, :taken_at)
  end
end

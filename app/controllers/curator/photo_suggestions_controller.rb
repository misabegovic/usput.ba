# frozen_string_literal: true

module Curator
  class PhotoSuggestionsController < BaseController
    before_action :set_location, only: [:new, :create]
    before_action :set_photo_suggestion, only: [:show]

    def index
      @photo_suggestions = current_user.photo_suggestions
        .includes(:location)
        .order(created_at: :desc)
        .page(params[:page]).per(20)
    end

    def show
    end

    def new
      @photo_suggestion = @location.photo_suggestions.new
    end

    def create
      @photo_suggestion = @location.photo_suggestions.build(photo_suggestion_params)
      @photo_suggestion.user = current_user

      if @photo_suggestion.save
        record_activity("photo_suggested", recordable: @photo_suggestion, metadata: {
          location_name: @location.name
        })
        redirect_to curator_location_path(@location), notice: t("curator.photo_suggestions.submitted")
      else
        flash.now[:alert] = @photo_suggestion.errors.full_messages.join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_location
      @location = Location.find_by_public_id!(params[:location_id])
    end

    def set_photo_suggestion
      @photo_suggestion = current_user.photo_suggestions.find(params[:id])
    end

    def photo_suggestion_params
      params.require(:photo_suggestion).permit(:photo, :photo_url, :description)
    end
  end
end

# frozen_string_literal: true

module Curator
  # Moderation queue for public moments: a curator approves or rejects the ones
  # travellers have chosen to publish. Only approved public moments are ever
  # served or searched (see Browse.syncable? and Moment.publicly_visible).
  class MomentsController < BaseController
    include ServesMomentPhotos

    before_action :set_moment, only: [ :approve, :reject ]

    def index
      scope = Moment.visibility_public_moment.with_attached_photo.includes(:user, :location).order(created_at: :desc)
      @moments = params[:status].present? ? scope.where(moderation_status: params[:status]) : scope.pending

      @stats = {
        pending: Moment.visibility_public_moment.pending.count,
        approved: Moment.visibility_public_moment.approved.count,
        rejected: Moment.visibility_public_moment.rejected.count
      }
    end

    def approve
      @moment.update!(moderation_status: :approved)
      record_activity(:approve_moment, recordable: @moment)
      redirect_to curator_moments_path, notice: t("curator.moments.flash.approved")
    end

    def reject
      @moment.update!(moderation_status: :rejected)
      record_activity(:reject_moment, recordable: @moment)
      redirect_to curator_moments_path, notice: t("curator.moments.flash.rejected")
    end

    # A curator reviews photos before they go public, so this serves any
    # public-intent moment regardless of moderation status — never a private one.
    def photo
      moment = Moment.visibility_public_moment.find_by_public_id!(params[:id])
      stream_moment_photo(moment, public: false)
    end

    private

    def set_moment
      @moment = Moment.find_by_public_id!(params[:id])
    end
  end
end

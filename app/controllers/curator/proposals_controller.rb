# frozen_string_literal: true

module Curator
  class ProposalsController < BaseController
    before_action :set_proposal, only: [:show, :add_review]

    def index
      @proposals = ContentChange.pending_review
        .includes(:user, :changeable, :contributions, :curator_reviews)
        .page(params[:page]).per(20)

      # Filter by type if specified
      if params[:change_type].present?
        @proposals = @proposals.where(change_type: params[:change_type])
      end

      # Filter by content type if specified
      if params[:content_type].present?
        @proposals = @proposals.where(changeable_type: params[:content_type])
          .or(@proposals.where(changeable_class: params[:content_type]))
      end
    end

    def show
      @review = CuratorReview.new
      @existing_review = @proposal.curator_reviews.find_by(user: current_user)
    end

    def add_review
      @review = @proposal.curator_reviews.build(review_params)
      @review.user = current_user

      if @review.save
        record_activity("review_added", recordable: @proposal, metadata: {
          recommendation: @review.recommendation,
          proposal_type: @proposal.change_type
        })
        redirect_to curator_proposal_path(@proposal), notice: t("curator.proposals.review_added")
      else
        @existing_review = @proposal.curator_reviews.find_by(user: current_user)
        flash.now[:alert] = @review.errors.full_messages.join(", ")
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_proposal
      @proposal = ContentChange.find(params[:id])
    end

    def review_params
      params.require(:curator_review).permit(:comment, :recommendation)
    end
  end
end

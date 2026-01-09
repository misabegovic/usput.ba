module Curator
  class PlansController < BaseController
    before_action :set_plan, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_options, only: [ :new, :create, :edit, :update ]

    def index
      @plans = Plan.includes(:user, :experiences).order(created_at: :desc)
      @plans = @plans.public_plans if params[:visibility] == "public"
      @plans = @plans.private_plans if params[:visibility] == "private"
      @plans = @plans.for_city(params[:city_name]) if params[:city_name].present?

      if params[:search].present?
        @plans = @plans.where("title ILIKE ?", "%#{params[:search]}%")
      end

      @plans = @plans.page(params[:page]).per(20)
      @city_names = Plan.where.not(city_name: [ nil, "" ]).distinct.pluck(:city_name).sort

      @stats = {
        total: Plan.count,
        public_plans: Plan.public_plans.count,
        private_plans: Plan.private_plans.count,
        with_experiences: Plan.joins(:plan_experiences).distinct.count
      }

      # Show pending proposals for this curator
      @pending_proposals = current_user.content_changes
        .where(changeable_type: "Plan")
        .or(current_user.content_changes.where(changeable_class: "Plan"))
        .pending
        .order(created_at: :desc)
    end

    def show
      @pending_proposal = pending_proposal_for(@plan)
    end

    def new
      @plan = Plan.new(visibility: :public_plan)
    end

    def create
      # Instead of creating directly, create a proposal for admin review
      proposal = current_user.content_changes.build(
        change_type: :create_content,
        changeable_class: "Plan",
        proposed_data: proposal_data_from_params
      )

      if proposal.save
        record_activity("proposal_created", recordable: proposal, metadata: { type: "Plan", title: proposal_data_from_params["title"] })
        redirect_to curator_plans_path, notice: t("curator.proposals.submitted_for_review")
      else
        @plan = Plan.new(plan_params)
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @pending_proposal = pending_proposal_for(@plan)
    end

    def update
      # Use find_or_create to ensure only one pending proposal per resource
      proposal = ContentChange.find_or_create_for_update(
        changeable: @plan,
        user: current_user,
        original_data: @plan.attributes.slice(*editable_attributes),
        proposed_data: proposal_data_from_params
      )

      if proposal.persisted?
        action = proposal.contributions.exists?(user: current_user) ? "proposal_contributed" : "proposal_updated"
        record_activity(action, recordable: @plan, metadata: { type: "Plan", title: @plan.title })
        redirect_to curator_plan_path(@plan), notice: t("curator.proposals.submitted_for_review")
      else
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Use find_or_create to ensure only one pending proposal per resource
      proposal = ContentChange.find_or_create_for_delete(
        changeable: @plan,
        user: current_user,
        original_data: @plan.attributes.slice(*editable_attributes)
      )

      if proposal.persisted?
        record_activity("proposal_deleted", recordable: @plan, metadata: { type: "Plan", title: @plan.title })
        redirect_to curator_plans_path, notice: t("curator.proposals.delete_submitted_for_review")
      else
        redirect_to curator_plans_path, alert: t("curator.proposals.failed_to_submit")
      end
    end

    private

    def set_plan
      @plan = Plan.find_by_public_id!(params[:id])
    end

    def editable_attributes
      %w[title notes city_name visibility start_date end_date]
    end

    def proposal_data_from_params
      data = plan_params.to_h
      # Include the user_id for new plans (will be the curator who proposed)
      data["user_id"] = current_user.id if action_name == "create"
      data
    end

    def plan_params
      params.require(:plan).permit(:title, :notes, :city_name, :visibility, :start_date, :end_date)
    end

    def load_form_options
      @city_names = Location.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
      @experiences = Experience.includes(:locations).order(:title)
    end
  end
end

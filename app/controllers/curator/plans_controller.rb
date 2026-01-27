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

      page = params[:items_page] || params[:page] || 1
      @plans = @plans.page(page).per(3)

      if params[:partial] == "items" && request.xhr?
        return render partial: "curator/plans/plan_items", locals: { plans: @plans }, layout: false
      end

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
        redirect_to curator_plans_path, notice: t("curator.proposals.submitted_for_review"), status: :see_other
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
        original_data: build_original_data,
        proposed_data: proposal_data_from_params
      )

      if proposal.persisted?
        action = proposal.contributions.exists?(user: current_user) ? "proposal_contributed" : "proposal_updated"
        record_activity(action, recordable: @plan, metadata: { type: "Plan", title: @plan.title })
        redirect_to curator_plan_path(@plan), notice: t("curator.proposals.submitted_for_review"), status: :see_other
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
        original_data: build_original_data
      )

      if proposal.persisted?
        record_activity("proposal_deleted", recordable: @plan, metadata: { type: "Plan", title: @plan.title })
        redirect_to curator_plans_path, notice: t("curator.proposals.delete_submitted_for_review"), status: :see_other
      else
        redirect_to curator_plans_path, alert: t("curator.proposals.failed_to_submit"), status: :see_other
      end
    end

    private

    def set_plan
      @plan = Plan.find_by_public_id!(params[:id])
    end

    def editable_attributes
      %w[title notes city_name visibility start_date end_date preferences]
    end

    def build_original_data
      data = @plan.attributes.slice(*editable_attributes)
      # Include current experience structure
      data["experience_days"] = build_current_experience_days
      data
    end

    def build_current_experience_days
      days = {}
      @plan.plan_experiences.includes(:experience).group_by(&:day_number).each do |day_num, plan_exps|
        days[day_num.to_s] = plan_exps.sort_by(&:position).map { |pe| pe.experience.uuid }
      end
      days
    end

    def proposal_data_from_params
      data = plan_params.to_h

      # Build preferences from form fields
      data["preferences"] = build_preferences_from_params

      # Include experience_uuids for managing plan experiences
      if params[:plan][:experience_days].present?
        data["experience_days"] = params[:plan][:experience_days].to_unsafe_h
      end

      # Include the user_id for new plans (will be the curator who proposed)
      data["user_id"] = current_user.id if action_name == "create"
      data
    end

    def build_preferences_from_params
      prefs = {}
      prefs["budget"] = params[:plan][:budget] if params[:plan][:budget].present?
      prefs["daily_hours"] = params[:plan][:daily_hours].to_i if params[:plan][:daily_hours].present?
      prefs["interests"] = params[:plan][:interests]&.reject(&:blank?) || []
      prefs["custom_title"] = params[:plan][:custom_title] if params[:plan][:custom_title].present?
      prefs
    end

    def plan_params
      params.require(:plan).permit(:title, :notes, :city_name, :visibility, :start_date, :end_date,
                                   :budget, :daily_hours, :custom_title, interests: [])
    end

    def load_form_options
      @city_names = Location.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
      @experiences = Experience.includes(:locations).order(:title)
      @experience_types = ExperienceType.active.order(:position)
    end
  end
end

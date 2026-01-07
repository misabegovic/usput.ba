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

      @city_names = Plan.where.not(city_name: [ nil, "" ]).distinct.pluck(:city_name).sort

      @stats = {
        total: Plan.count,
        public_plans: Plan.public_plans.count,
        private_plans: Plan.private_plans.count,
        with_experiences: Plan.joins(:plan_experiences).distinct.count
      }
    end

    def show
    end

    def new
      @plan = Plan.new(visibility: :public_plan)
    end

    def create
      @plan = Plan.new(plan_params)
      @plan.user = current_user

      if @plan.save
        redirect_to curator_plan_path(@plan), notice: t("curator.plans.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @plan.update(plan_params)
        redirect_to curator_plan_path(@plan), notice: t("curator.plans.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @plan.destroy
      redirect_to curator_plans_path, notice: t("curator.plans.deleted")
    end

    private

    def set_plan
      @plan = Plan.find_by_public_id!(params[:id])
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

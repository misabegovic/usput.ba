class UserPlansController < ApplicationController
  before_action :require_login
  before_action :set_plan, only: [:show, :update, :destroy, :toggle_visibility]

  # Accept both form and JSON requests
  protect_from_forgery with: :null_session, if: -> { request.format.json? }

  # GET /user/plans
  # Dohvati sve planove korisnika
  def index
    plans = current_user.plans.includes(plan_experiences: { experience: :locations })
                        .order(created_at: :desc)

    render json: {
      plans: plans.map(&:to_local_storage_format)
    }
  end

  # GET /user/plans/:id
  def show
    render json: @plan.to_local_storage_format
  end

  # POST /user/plans/sync
  # Sinkroniziraj planove iz localStorage-a
  def sync
    local_plans = params[:plans] || []
    synced_plans = []
    errors = []

    local_plans.each do |plan_data|
      plan_data = plan_data.to_unsafe_h if plan_data.respond_to?(:to_unsafe_h)
      result = sync_single_plan(plan_data)

      if result[:success]
        synced_plans << result[:plan].to_local_storage_format
      else
        errors << { local_id: plan_data["id"], error: result[:error] }
      end
    end

    # Also get any plans that exist in DB but not in local
    existing_local_ids = local_plans.map { |p| p["id"] }.compact
    db_only_plans = current_user.plans.where.not(local_id: existing_local_ids)
                                .or(current_user.plans.where(local_id: nil))
                                .includes(plan_experiences: { experience: :locations })

    db_only_plans.each do |plan|
      synced_plans << plan.to_local_storage_format
    end

    render json: {
      success: errors.empty?,
      plans: synced_plans,
      errors: errors
    }
  end

  # POST /user/plans
  # Kreiraj novi plan
  def create
    plan_data = plan_params.to_h
    result = Plan.create_from_local_storage(plan_data, user: current_user)
    plan = result[:plan]

    if plan&.persisted?
      response_data = plan.to_local_storage_format
      response_data[:warnings] = result[:warnings] if result[:warnings].present?
      render json: response_data, status: :created
    else
      render json: { error: I18n.t("plans.errors.invalid_plan_data"), details: plan&.errors&.full_messages },
             status: :unprocessable_entity
    end
  end

  # PATCH/PUT /user/plans/:id
  def update
    plan_data = plan_params.to_h
    result = @plan.update_from_local_storage(plan_data)

    if result[:success]
      response_data = @plan.to_local_storage_format
      response_data[:warnings] = result[:warnings] if result[:warnings].present?
      render json: response_data
    else
      render json: { error: "Failed to update plan", details: @plan.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # DELETE /user/plans/:id
  def destroy
    @plan.destroy
    head :no_content
  end

  # POST /user/plans/share
  # Podijeli plan sa zajednicom (učini ga javnim)
  def share
    plan_data = params[:plan]

    if plan_data.blank?
      render json: { success: false, error: "No plan data provided" }, status: :unprocessable_entity
      return
    end

    plan_data = plan_data.to_unsafe_h if plan_data.respond_to?(:to_unsafe_h)
    local_id = plan_data["id"]
    warnings = []

    # Check if plan already exists for this user
    existing_plan = current_user.plans.find_by(local_id: local_id)

    if existing_plan
      # Update existing plan and make it public
      result = existing_plan.update_from_local_storage(plan_data)
      warnings.concat(result[:warnings]) if result[:warnings].present?
      plan = existing_plan
    else
      # Create new plan
      result = Plan.create_from_local_storage(plan_data, user: current_user)
      plan = result[:plan]
      warnings.concat(result[:warnings]) if result[:warnings].present?
    end

    if plan&.persisted?
      plan.update!(visibility: :public_plan)

      render json: {
        success: true,
        plan_id: plan.uuid,
        plan_url: plan_path(plan),
        warnings: warnings.presence
      }.compact
    else
      error_msg = plan&.errors&.full_messages&.join(", ") || "Failed to create plan"
      Rails.logger.error "Share plan validation error: #{error_msg}"
      render json: { success: false, error: error_msg, warnings: warnings.presence }.compact, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Share plan error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # POST /user/plans/:id/toggle_visibility
  # Promijeni vidljivost plana (javan/privatan)
  def toggle_visibility
    new_visibility = @plan.visibility_public_plan? ? :private_plan : :public_plan

    if @plan.update(visibility: new_visibility)
      render json: {
        success: true,
        visibility: @plan.visibility,
        is_public: @plan.visibility_public_plan?,
        plan_url: @plan.visibility_public_plan? ? plan_path(@plan) : nil
      }
    else
      render json: { success: false, error: @plan.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def require_login
    unless logged_in?
      render json: { error: "Authentication required" }, status: :unauthorized
    end
  end

  def set_plan
    # Look up by UUID first, then by local_id for backwards compatibility
    @plan = current_user.plans.find_by(uuid: params[:id]) ||
            current_user.plans.find_by(local_id: params[:id])

    unless @plan
      render json: { error: "Plan not found" }, status: :not_found
      return
    end
  end

  def plan_params
    params.require(:plan).permit(
      :id, :generated_at, :duration_days, :saved, :savedAt, :custom_title, :notes,
      city: [:id, :name, :display_name],
      preferences: [:budget, :meat_lover, :custom_title, interests: []],
      days: [:day_number, :date, experiences: [:id, :title, :description, :formatted_duration, locations: []]]
    )
  end

  def sync_single_plan(plan_data)
    local_id = plan_data["id"]
    warnings = []

    # Check if plan already exists
    existing_plan = current_user.plans.find_by(local_id: local_id)

    if existing_plan
      # Update existing plan
      result = existing_plan.update_from_local_storage(plan_data)
      warnings.concat(result[:warnings]) if result[:warnings].present?

      if result[:success]
        { success: true, plan: existing_plan, warnings: warnings }
      else
        { success: false, error: existing_plan.errors.full_messages.join(", "), warnings: warnings }
      end
    else
      # Create new plan
      result = Plan.create_from_local_storage(plan_data, user: current_user)
      plan = result[:plan]
      warnings.concat(result[:warnings]) if result[:warnings].present?

      if plan&.persisted?
        { success: true, plan: plan, warnings: warnings }
      else
        { success: false, error: plan&.errors&.full_messages&.join(", ") || "Unknown error", warnings: warnings }
      end
    end
  end
end

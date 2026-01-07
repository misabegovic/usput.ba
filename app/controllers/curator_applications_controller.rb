class CuratorApplicationsController < ApplicationController
  before_action :require_login, except: [ :info ]
  before_action :ensure_can_apply, only: [ :new, :create ]

  def info
    # Public page - anyone can view info about becoming a curator
  end

  def new
    @application = CuratorApplication.new
  end

  def create
    @application = current_user.curator_applications.build(application_params)

    if @application.save
      redirect_to curator_application_path(@application),
        notice: t("curator_applications.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @application = current_user.curator_applications.find_by!(uuid: params[:id])
  end

  private

  def application_params
    params.require(:curator_application).permit(:motivation, :experience)
  end

  def ensure_can_apply
    unless current_user.can_apply_for_curator?
      if current_user.can_curate?
        redirect_to root_path, alert: t("curator_applications.errors.already_curator")
      else
        redirect_to root_path, alert: t("curator_applications.errors.pending_exists")
      end
    end
  end
end

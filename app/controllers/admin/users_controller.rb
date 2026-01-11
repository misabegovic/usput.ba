module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = User.order(created_at: :desc)
      @users = @users.where(user_type: params[:user_type]) if params[:user_type].present?
    end

    def show
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: t("admin.users.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: t("admin.users.cannot_delete_self")
      else
        @user.destroy
        redirect_to admin_users_path, notice: t("admin.users.deleted")
      end
    end

    private

    def set_user
      @user = User.find_by_public_id!(params[:id])
    end

    def user_params
      params.require(:user).permit(:user_type)
    end
  end
end

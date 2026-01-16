# frozen_string_literal: true

module Curator
  module Admin
    # User management controller for admin users.
    # Allows admins to view, edit, and manage user accounts.
    class UsersController < BaseController
      before_action :set_user, only: [:show, :edit, :update, :unblock]

      def index
        @users = User.order(created_at: :desc)
        @users = @users.where(user_type: params[:user_type]) if valid_user_type?(params[:user_type])
        @users = @users.where("spam_blocked_until > ?", Time.current) if params[:blocked] == "true"

        @stats = {
          total: User.count,
          basic: User.basic.count,
          curator: User.curator.count,
          admin: User.admin.count,
          blocked: User.where("spam_blocked_until > ?", Time.current).count
        }
      end

      def show
        @activities = @user.curator_activities.recent.limit(20) if @user.curator?
      end

      def edit
      end

      def update
        if @user.update(user_params)
          record_activity(:update_user, recordable: @user, metadata: { changes: @user.previous_changes })
          redirect_to curator_admin_user_path(@user),
            notice: t("curator.admin.users.updated")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def unblock
        if @user.spam_blocked?
          @user.admin_unblock!
          record_activity(:unblock_user, recordable: @user)
          redirect_to curator_admin_user_path(@user),
            notice: t("curator.admin.users.unblocked")
        else
          redirect_to curator_admin_user_path(@user),
            alert: t("curator.admin.users.not_blocked")
        end
      end

      private

      def set_user
        @user = User.find_by_public_id!(params[:id])
      end

      def user_params
        params.require(:user).permit(:user_type)
      end

      def valid_user_type?(user_type)
        user_type.present? && User.user_types.key?(user_type.to_s)
      end
    end
  end
end

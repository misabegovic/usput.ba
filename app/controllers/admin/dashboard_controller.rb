module Admin
  class DashboardController < BaseController
    def index
      @stats = {
        total_users: User.count,
        basic_users: User.basic.count,
        curator_users: User.curator.count,
        locations_count: Location.count,
        experiences_count: Experience.count,
        cities_count: Location.distinct.count(:city),
        recent_users: User.order(created_at: :desc).limit(10)
      }
    end

    def clear_database
      confirmation = params[:confirmation_text]

      if confirmation != "DELETE ALL"
        redirect_to admin_root_path, alert: t("admin.dashboard.invalid_confirmation")
        return
      end

      ActiveRecord::Base.transaction do
        # Delete in order to avoid foreign key constraints
        CuratorApplication.delete_all
        Review.delete_all
        PlanExperience.delete_all
        Plan.delete_all
        AudioTour.delete_all
        Browse.delete_all
        Translation.delete_all
        ExperienceLocation.delete_all
        LocationExperienceType.delete_all
        LocationCategoryAssignment.delete_all
        Experience.delete_all
        Location.delete_all
        ExperienceCategoryType.delete_all
        ExperienceCategory.delete_all
        LocationCategory.delete_all
        ExperienceType.delete_all
        Locale.delete_all
        AiGeneration.delete_all
        Setting.delete_all
        User.delete_all

        # Clear ActiveStorage (order matters due to foreign keys)
        ActiveStorage::VariantRecord.delete_all
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
      end

      redirect_to admin_root_path, notice: t("admin.dashboard.database_cleared")
    end
  end
end

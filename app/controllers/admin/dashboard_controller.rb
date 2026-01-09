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
        recent_users: User.order(created_at: :desc).limit(10),
        pending_proposals: ContentChange.pending.count,
        pending_photo_suggestions: PhotoSuggestion.pending.count,
        blocked_curators: User.curator.where.not(spam_blocked_until: nil).where("spam_blocked_until > ?", Time.current).count
      }

      # Recent curator activities (paginated)
      @recent_activities = CuratorActivity.includes(:user, :recordable)
        .recent
        .page(params[:page]).per(15)
    end
  end
end

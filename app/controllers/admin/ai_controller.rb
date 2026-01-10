# frozen_string_literal: true

module Admin
  # Controller za autonomni AI Content Generator
  # Admin samo klikne jedan gumb - AI odlucuje SVE
  class AiController < BaseController
    before_action :require_admin_credentials, only: [
      :generate, :stop, :reset,
      :fix_cities, :force_reset_city_fix,
      :sync_experience_types, :force_reset_experience_type_sync,
      :rebuild_experiences, :force_reset_rebuild_experiences,
      :rebuild_plans, :force_reset_rebuild_plans,
      :regenerate_translations, :force_reset_regenerate_translations,
      :fetch_wikimedia_images, :force_reset_wikimedia_fetch,
      :fetch_google_images, :force_reset_google_image_fetch
    ]

    # GET /admin/ai
    # Dashboard sa statistikama i gumbom za generiranje
    def index
      @stats = ::Ai::ContentOrchestrator.content_stats
      @generation_status = ::Ai::ContentOrchestrator.current_status
      @fix_cities_status = LocationCityFixJob.current_status
      @experience_type_sync_status = ExperienceTypeSyncJob.current_status
      @rebuild_experiences_status = RebuildExperiencesJob.current_status
      @rebuild_plans_status = RebuildPlansJob.current_status
      @regenerate_translations_status = RegenerateTranslationsJob.status
      @dirty_counts = RegenerateTranslationsJob.dirty_counts
      @wikimedia_fetch_status = WikimediaImageFetchJob.current_status
      @google_image_fetch_status = LocationImageFinderJob.current_status
      @locations_without_photos_count = count_locations_without_photos
      @last_generation = parse_last_generation

      # Paginate cities for the table
      all_cities = @stats[:cities] || []
      @cities_page = params[:page].to_i
      @cities_page = 1 if @cities_page < 1
      @cities_per_page = 15
      @cities_total_pages = (all_cities.count.to_f / @cities_per_page).ceil
      @cities_total_pages = 1 if @cities_total_pages < 1
      start_index = (@cities_page - 1) * @cities_per_page
      @paginated_cities = all_cities[start_index, @cities_per_page] || []
    end

    # POST /admin/ai/generate
    # Pokrece autonomno AI generiranje
    def generate
      # Parse max values - empty string means "use default", "0" means unlimited
      max_locations = parse_max_param(params[:max_locations])
      max_experiences = parse_max_param(params[:max_experiences])
      max_plans = parse_max_param(params[:max_plans])
      skip_locations = params[:skip_locations] == "1"
      skip_experiences = params[:skip_experiences] == "1"
      skip_plans = params[:skip_plans] == "1"

      # Provjeri da li je vec u toku
      current_status = ::Ai::ContentOrchestrator.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.already_in_progress")
        return
      end

      # Pokreni job
      ContentGenerationJob.perform_later(
        max_locations: max_locations,
        max_experiences: max_experiences,
        max_plans: max_plans,
        skip_locations: skip_locations,
        skip_experiences: skip_experiences,
        skip_plans: skip_plans
      )

      redirect_to admin_ai_path, notice: t("admin.ai.generation_started")
    end

    # GET /admin/ai/status (AJAX)
    # Vraca trenutni status generiranja
    def status
      @generation_status = ::Ai::ContentOrchestrator.current_status

      respond_to do |format|
        format.json { render json: @generation_status }
        format.html { render partial: "status", locals: { status: @generation_status } }
      end
    end

    # GET /admin/ai/report
    # Detaljan izvjestaj posljednjeg generiranja
    def report
      @generation_status = ::Ai::ContentOrchestrator.current_status
      @results = @generation_status[:results] || {}
    end

    # POST /admin/ai/stop
    # Zaustavlja trenutno generiranje
    def stop
      current_status = ::Ai::ContentOrchestrator.current_status
      unless current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.not_in_progress")
        return
      end

      ::Ai::ContentOrchestrator.cancel_generation!
      redirect_to admin_ai_path, notice: t("admin.ai.generation_stopped")
    end

    # POST /admin/ai/reset
    # Force-resets a stuck generation status back to idle
    def reset
      ::Ai::ContentOrchestrator.force_reset!
      redirect_to admin_ai_path, notice: t("admin.ai.generation_reset")
    end

    # POST /admin/ai/fix_cities
    # Runs reverse geocoding on all locations to fix incorrect city names
    def fix_cities
      current_status = LocationCityFixJob.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.city_fix_already_in_progress", default: "City fix is already in progress")
        return
      end

      regenerate_content = params[:regenerate_content] == "1"
      analyze_descriptions = params[:analyze_descriptions] == "1"
      dry_run = params[:dry_run] == "1"
      clear_cache = params[:clear_cache] == "1"

      LocationCityFixJob.clear_status!
      LocationCityFixJob.perform_later(
        regenerate_content: regenerate_content,
        analyze_descriptions: analyze_descriptions,
        dry_run: dry_run,
        clear_cache: clear_cache
      )

      notice_msg = if dry_run
        t("admin.ai.city_fix_preview_started", default: "City fix preview started (no changes will be made)")
      elsif regenerate_content
        t("admin.ai.city_fix_with_content_started", default: "City fix started with content regeneration")
      else
        t("admin.ai.city_fix_started", default: "City fix started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/fix_cities_status (AJAX)
    # Returns current status of city fix job
    def fix_cities_status
      @fix_status = LocationCityFixJob.current_status

      respond_to do |format|
        format.json { render json: @fix_status }
        format.html { render partial: "fix_cities_status", locals: { status: @fix_status } }
      end
    end

    # POST /admin/ai/force_reset_city_fix
    # Force resets a stuck or in-progress city fix job
    def force_reset_city_fix
      LocationCityFixJob.force_reset_city_fix!
      redirect_to admin_ai_path, notice: t("admin.ai.city_fix_force_reset", default: "City fix has been force reset. You can now start a new run.")
    end

    # POST /admin/ai/sync_experience_types
    # Syncs experience types from location suitable_experiences JSONB to the join table
    def sync_experience_types
      current_status = ExperienceTypeSyncJob.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.experience_type_sync_already_in_progress", default: "Experience type sync is already in progress")
        return
      end

      dry_run = params[:dry_run] == "1"

      ExperienceTypeSyncJob.clear_status!
      ExperienceTypeSyncJob.perform_later(dry_run: dry_run)

      notice_msg = if dry_run
        t("admin.ai.experience_type_sync_preview_started", default: "Experience type sync preview started (no changes will be made)")
      else
        t("admin.ai.experience_type_sync_started", default: "Experience type sync started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/sync_experience_types_status (AJAX)
    # Returns current status of experience type sync job
    def sync_experience_types_status
      @sync_status = ExperienceTypeSyncJob.current_status

      respond_to do |format|
        format.json { render json: @sync_status }
        format.html { render partial: "experience_type_sync_status", locals: { status: @sync_status } }
      end
    end

    # POST /admin/ai/force_reset_experience_type_sync
    # Force resets a stuck or in-progress experience type sync job
    def force_reset_experience_type_sync
      ExperienceTypeSyncJob.force_reset!
      redirect_to admin_ai_path, notice: t("admin.ai.experience_type_sync_force_reset", default: "Experience type sync has been force reset. You can now start a new run.")
    end

    # POST /admin/ai/rebuild_experiences
    # Analyzes and rebuilds experiences with quality issues or high similarity
    def rebuild_experiences
      current_status = RebuildExperiencesJob.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.rebuild_experiences_already_in_progress", default: "Experience rebuild is already in progress")
        return
      end

      dry_run = params[:dry_run] == "1"
      rebuild_mode = params[:rebuild_mode].presence || "all"
      max_rebuilds = params[:max_rebuilds].presence&.to_i
      delete_similar = params[:delete_similar] == "1"
      delete_orphaned = params[:delete_orphaned] == "1"

      RebuildExperiencesJob.clear_status!
      RebuildExperiencesJob.perform_later(
        dry_run: dry_run,
        rebuild_mode: rebuild_mode,
        max_rebuilds: max_rebuilds,
        delete_similar: delete_similar,
        delete_orphaned: delete_orphaned
      )

      notice_msg = if dry_run
        t("admin.ai.rebuild_experiences_preview_started", default: "Experience analysis started (preview mode - no changes will be made)")
      else
        t("admin.ai.rebuild_experiences_started", default: "Experience rebuild started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/rebuild_experiences_status (AJAX)
    # Returns current status of rebuild experiences job
    def rebuild_experiences_status
      @rebuild_status = RebuildExperiencesJob.current_status

      respond_to do |format|
        format.json { render json: @rebuild_status }
        format.html { render partial: "rebuild_experiences_status", locals: { status: @rebuild_status } }
      end
    end

    # POST /admin/ai/force_reset_rebuild_experiences
    # Force resets a stuck or in-progress rebuild experiences job
    def force_reset_rebuild_experiences
      RebuildExperiencesJob.force_reset!
      redirect_to admin_ai_path, notice: t("admin.ai.rebuild_experiences_force_reset", default: "Experience rebuild has been force reset. You can now start a new run.")
    end

    # POST /admin/ai/rebuild_plans
    # Analyzes and rebuilds plans with quality issues or high similarity
    def rebuild_plans
      current_status = RebuildPlansJob.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.rebuild_plans_already_in_progress", default: "Plan rebuild is already in progress")
        return
      end

      dry_run = params[:dry_run] == "1"
      rebuild_mode = params[:rebuild_mode].presence || "all"
      max_rebuilds = params[:max_rebuilds].presence&.to_i
      delete_similar = params[:delete_similar] == "1"

      RebuildPlansJob.clear_status!
      RebuildPlansJob.perform_later(
        dry_run: dry_run,
        rebuild_mode: rebuild_mode,
        max_rebuilds: max_rebuilds,
        delete_similar: delete_similar
      )

      notice_msg = if dry_run
        t("admin.ai.rebuild_plans_preview_started", default: "Plan analysis started (preview mode - no changes will be made)")
      else
        t("admin.ai.rebuild_plans_started", default: "Plan rebuild started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/rebuild_plans_status (AJAX)
    # Returns current status of rebuild plans job
    def rebuild_plans_status
      @rebuild_status = RebuildPlansJob.current_status

      respond_to do |format|
        format.json { render json: @rebuild_status }
        format.html { render partial: "rebuild_plans_status", locals: { status: @rebuild_status } }
      end
    end

    # POST /admin/ai/force_reset_rebuild_plans
    # Force resets a stuck or in-progress rebuild plans job
    def force_reset_rebuild_plans
      RebuildPlansJob.force_reset!
      redirect_to admin_ai_path, notice: t("admin.ai.rebuild_plans_force_reset", default: "Plan rebuild has been force reset. You can now start a new run.")
    end

    # POST /admin/ai/regenerate_translations
    # Regenerates translations and audio tours for dirty resources
    def regenerate_translations
      if RegenerateTranslationsJob.in_progress?
        redirect_to admin_ai_path, alert: t("admin.ai.regenerate_translations_already_in_progress", default: "Translation regeneration is already in progress")
        return
      end

      dry_run = params[:dry_run] == "1"
      include_audio = params[:include_audio] != "0"

      RegenerateTranslationsJob.reset_status!
      RegenerateTranslationsJob.perform_later(dry_run: dry_run, include_audio: include_audio)

      notice_msg = if dry_run
        t("admin.ai.regenerate_translations_preview_started", default: "Translation regeneration preview started (no changes will be made)")
      else
        t("admin.ai.regenerate_translations_started", default: "Translation regeneration started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/regenerate_translations_status (AJAX)
    # Returns current status of translation regeneration job
    def regenerate_translations_status
      status = RegenerateTranslationsJob.status
      progress = RegenerateTranslationsJob.progress

      respond_to do |format|
        format.json { render json: { status: status, progress: progress } }
        format.html { render partial: "regenerate_translations_status", locals: { status: status, progress: progress } }
      end
    end

    # POST /admin/ai/force_reset_regenerate_translations
    # Force resets a stuck or in-progress translation regeneration job
    def force_reset_regenerate_translations
      RegenerateTranslationsJob.reset_status!
      redirect_to admin_ai_path, notice: t("admin.ai.regenerate_translations_force_reset", default: "Translation regeneration has been force reset. You can now start a new run.")
    end

    # POST /admin/ai/fetch_wikimedia_images
    # Fetches images from Wikimedia Commons for locations without photos
    def fetch_wikimedia_images
      current_status = WikimediaImageFetchJob.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.wikimedia_fetch_already_in_progress", default: "Wikimedia image fetch is already in progress")
        return
      end

      dry_run = params[:dry_run] == "1"
      max_locations = params[:max_locations].presence&.to_i || 10
      images_per_location = params[:images_per_location].presence&.to_i || 5
      use_coordinates = params[:use_coordinates] != "0"
      replace_photos = params[:replace_photos] == "1"

      WikimediaImageFetchJob.clear_status!
      WikimediaImageFetchJob.perform_later(
        dry_run: dry_run,
        max_locations: max_locations,
        images_per_location: images_per_location,
        use_coordinates: use_coordinates,
        replace_photos: replace_photos
      )

      notice_msg = if dry_run
        t("admin.ai.wikimedia_fetch_preview_started", default: "Wikimedia image fetch preview started (no images will be attached)")
      elsif replace_photos
        t("admin.ai.wikimedia_fetch_replace_started", default: "Wikimedia image fetch started (replacing existing photos)")
      else
        t("admin.ai.wikimedia_fetch_started", default: "Wikimedia image fetch started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/fetch_wikimedia_images_status (AJAX)
    # Returns current status of Wikimedia image fetch job
    def fetch_wikimedia_images_status
      @wikimedia_status = WikimediaImageFetchJob.current_status

      respond_to do |format|
        format.json { render json: @wikimedia_status }
        format.html { render partial: "wikimedia_images_status", locals: { status: @wikimedia_status } }
      end
    end

    # POST /admin/ai/force_reset_wikimedia_fetch
    # Force resets a stuck or in-progress Wikimedia fetch job
    def force_reset_wikimedia_fetch
      WikimediaImageFetchJob.force_reset!
      redirect_to admin_ai_path, notice: t("admin.ai.wikimedia_fetch_force_reset", default: "Wikimedia image fetch has been force reset. You can now start a new run.")
    end

    # POST /admin/ai/fetch_google_images
    # Fetches images from Google Custom Search for locations without photos
    def fetch_google_images
      current_status = LocationImageFinderJob.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.google_image_fetch_already_in_progress", default: "Google image fetch is already in progress")
        return
      end

      dry_run = params[:dry_run] == "1"
      max_locations = params[:max_locations].presence&.to_i || 10
      images_per_location = params[:images_per_location].presence&.to_i || 3
      creative_commons_only = params[:creative_commons_only] == "1"
      replace_photos = params[:replace_photos] == "1"

      LocationImageFinderJob.clear_status!
      LocationImageFinderJob.perform_later(
        dry_run: dry_run,
        max_locations: max_locations,
        images_per_location: images_per_location,
        creative_commons_only: creative_commons_only,
        replace_photos: replace_photos
      )

      notice_msg = if dry_run
        t("admin.ai.google_image_fetch_preview_started", default: "Google image search preview started (no images will be attached)")
      elsif replace_photos
        t("admin.ai.google_image_fetch_replace_started", default: "Google image search started (replacing existing photos)")
      else
        t("admin.ai.google_image_fetch_started", default: "Google image search started")
      end

      redirect_to admin_ai_path, notice: notice_msg
    end

    # GET /admin/ai/fetch_google_images_status (AJAX)
    # Returns current status of Google image fetch job
    def fetch_google_images_status
      @google_image_status = LocationImageFinderJob.current_status

      respond_to do |format|
        format.json { render json: @google_image_status }
        format.html { render partial: "google_images_status", locals: { status: @google_image_status } }
      end
    end

    # POST /admin/ai/force_reset_google_image_fetch
    # Force resets a stuck or in-progress Google image fetch job
    def force_reset_google_image_fetch
      LocationImageFinderJob.force_reset!
      redirect_to admin_ai_path, notice: t("admin.ai.google_image_fetch_force_reset", default: "Google image fetch has been force reset. You can now start a new run.")
    end

    private

    # Parse max param: empty/nil = use default, "0" = unlimited (pass 0), other = specific value
    def parse_max_param(value)
      return nil if value.blank? # Use default
      int_value = value.to_i
      int_value # 0 means unlimited, other values are specific limits
    end

    def parse_last_generation
      status = ::Ai::ContentOrchestrator.current_status
      return nil if status[:started_at].blank?

      {
        started_at: Time.parse(status[:started_at]),
        status: status[:status],
        message: status[:message],
        plan: status[:plan],
        results: status[:results]
      }
    rescue ArgumentError
      nil
    end

    # Count locations without any attached photos
    def count_locations_without_photos
      locations_with_photos_ids = ActiveStorage::Attachment
        .where(record_type: "Location", name: "photos")
        .distinct
        .pluck(:record_id)

      Location.where.not(id: locations_with_photos_ids).count
    end
  end
end

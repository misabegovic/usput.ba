# frozen_string_literal: true

module Admin
  # Controller za autonomni AI Content Generator
  # Admin samo klikne jedan gumb - AI odlucuje SVE
  class AiController < BaseController
    # GET /admin/ai
    # Dashboard sa statistikama i gumbom za generiranje
    def index
      @stats = ::Ai::ContentOrchestrator.content_stats
      @generation_status = ::Ai::ContentOrchestrator.current_status
      @fix_cities_status = LocationCityFixJob.current_status
      @last_generation = parse_last_generation
    end

    # POST /admin/ai/generate
    # Pokrece autonomno AI generiranje
    def generate
      max_experiences = params[:max_experiences].presence&.to_i

      # Provjeri da li je vec u toku
      current_status = ::Ai::ContentOrchestrator.current_status
      if current_status[:status] == "in_progress"
        redirect_to admin_ai_path, alert: t("admin.ai.already_in_progress")
        return
      end

      # Pokreni job
      ContentGenerationJob.perform_later(max_experiences: max_experiences)

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
      dry_run = params[:dry_run] == "1"
      clear_cache = params[:clear_cache] == "1"

      LocationCityFixJob.clear_status!
      LocationCityFixJob.perform_later(regenerate_content: regenerate_content, dry_run: dry_run, clear_cache: clear_cache)

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

    private

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
  end
end

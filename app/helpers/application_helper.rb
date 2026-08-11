module ApplicationHelper
  # Admins review the walk without standing at the place. An env-var bypass used
  # to cover development, but it only ever lifted the distance check — the deck
  # still needs coordinates to deal from — so it never made a usable dev flow.
  # Development only. A laptop has no GPS, so working on the walk otherwise
  # means waiting on a network lookup that often never answers.
  def dev_position
    return nil unless Rails.env.development?
    ENV["DEV_POSITION"].presence
  end

  def geofence_disabled?
    current_user_admin?
  end

  # Names the traveller's device store without naming the traveller. The browser
  # keeps its profile reads synchronous, and its only digest is asynchronous, so
  # the hash is taken here — which also stops the account id being left behind on
  # a shared machine. Obfuscation, not a boundary: the page carries it in clear.
  def travel_store_scope
    return nil unless logged_in?

    Digest::SHA256.hexdigest(current_user.uuid)[0, 16]
  end

  # Curator-supplied urls are rendered as hrefs, and Rails does not escape the
  # scheme — `javascript:alert(1)` would run on click. Only absolute http(s)
  # survives; anything else comes back nil so the caller prints text instead.
  def safe_external_url(url)
    parsed = URI.parse(url.to_s.strip)
    return nil unless parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)
    return nil if parsed.host.blank?

    parsed.to_s
  rescue URI::InvalidURIError
    nil
  end

  # Stamps the catalogue so a browser holding an old copy can tell. Rails builds
  # this from count plus max(updated_at) in one query — seconds alone collide
  # when several places are written inside the same second.
  # Called by the controller and again by every map on the page; the count and
  # max behind it are one query too many, let alone several.
  def map_points_version
    @map_points_version ||= Location.all.cache_key_with_version.parameterize
  end

  # Where signing in should land the visitor. A frame is fetched at its own url,
  # so for those the page to come back to is the one that asked for the frame.
  def sign_in_return_path
    path = if request.headers["Turbo-Frame"].present?
      URI.parse(request.referer.to_s).path
    else
      request.fullpath
    end

    path.to_s.match?(%r{\A/(?!/)}) ? path : root_path
  rescue URI::InvalidURIError
    root_path
  end

  # Human-readable label for a location category key.
  #
  # A blank key must never be interpolated straight into the I18n lookup: a key
  # like "locations.types." resolves to the *parent* hash and I18n returns the
  # whole { place: ..., guide: ... } Hash, which then renders as raw text on the
  # page. Uncategorized locations are places by definition (see Location#place_type?),
  # so we fall back to the "place" type.
  # @param category_key [String, nil] The location's category key
  # @return [String] The translated type label (e.g. "Place" / "Mjesto")
  def location_type_label(category_key)
    key = category_key.presence || "place"
    t("locations.types.#{key}", default: key.to_s.humanize)
  end

  # A blank season key would resolve to the parent hash and render it raw; the
  # seasons array carries a blank from the form's empty-array hidden field, and
  # an experience with no seasons is year-round by definition.
  def experience_season_label(season)
    key = season.presence || "all_year"
    t("curator.experiences.seasons.#{key}", default: key.to_s.humanize)
  end

  # Safely renders an ActiveStorage attachment image, handling missing files gracefully
  # @param attachment [ActiveStorage::Attached, ActiveStorage::Attachment] The attachment to render
  # @param variant_options [Hash] Options to pass to variant() (e.g., resize_to_fill: [400, 300])
  # @param fallback [String, nil] Path to fallback image or nil to return nil
  # @param options [Hash] Options to pass to image_tag
  # @return [String, nil] The image tag HTML or nil if no image available
  def safe_attachment_image_tag(attachment, variant_options: nil, fallback: nil, **options)
    return fallback_image_tag(fallback, options) unless attachment_present?(attachment)

    begin
      if variant_options && attachment.variable?
        image_tag attachment.variant(variant_options), **options
      else
        image_tag attachment, **options
      end
    rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvariableError => e
      Rails.logger.warn "[ActiveStorage] Failed to render attachment: #{e.message}"
      fallback_image_tag(fallback, options)
    end
  end

  # Safely gets the URL for an ActiveStorage attachment
  # @param attachment [ActiveStorage::Attached, ActiveStorage::Attachment] The attachment
  # @param variant_options [Hash] Options to pass to variant() if needed
  # @return [String, nil] The URL or nil if not available
  def safe_attachment_url(attachment, variant_options: nil)
    return nil unless attachment_present?(attachment)

    begin
      if variant_options && attachment.variable?
        rails_representation_url(attachment.variant(variant_options))
      else
        rails_blob_url(attachment)
      end
    rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvariableError => e
      Rails.logger.warn "[ActiveStorage] Failed to get attachment URL: #{e.message}"
      nil
    end
  end

  # Safely gets the path for an ActiveStorage attachment
  # @param attachment [ActiveStorage::Attached, ActiveStorage::Attachment] The attachment
  # @param only_path [Boolean] Whether to return only the path (default: true)
  # @return [String, nil] The path or nil if not available
  def safe_attachment_path(attachment, only_path: true)
    return nil unless attachment_present?(attachment)

    begin
      rails_blob_path(attachment, only_path: only_path)
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.warn "[ActiveStorage] Failed to get attachment path: #{e.message}"
      nil
    end
  end

  private

  def fallback_image_tag(fallback, options)
    return nil if fallback.nil?
    image_tag(fallback, **options)
  end

  # Checks if an attachment is present, handling both ActiveStorage::Attached proxies
  # and ActiveStorage::Attachment objects
  # @param attachment [ActiveStorage::Attached, ActiveStorage::Attachment, nil] The attachment to check
  # @return [Boolean] true if the attachment is present and usable
  def attachment_present?(attachment)
    return false if attachment.nil?

    # ActiveStorage::Attached::One/Many proxies respond to attached?
    if attachment.respond_to?(:attached?)
      attachment.attached?
    else
      # ActiveStorage::Attachment objects are already "attached" if they exist
      # Check for blob presence to ensure the attachment is valid
      attachment.respond_to?(:blob) && attachment.blob.present?
    end
  end

  public

  # Memoized per request so a grid of cards costs one query, not one each.
  def visited_location_ids
    @visited_location_ids ||= if logged_in?
      current_user.plan_visits.distinct.pluck(:location_id).to_set
    else
      Set.new
    end
  end

  def visited_location?(location)
    visited_location_ids.include?(location.id)
  end

  # One grouped count per request. Plans the traveller never touched short-
  # circuit before we ask a plan how many locations it holds.
  def plan_visit_counts
    @plan_visit_counts ||= logged_in? ? current_user.plan_visits.group(:plan_id).count : {}
  end

  def plan_progress(plan)
    visited = plan_visit_counts[plan.id].to_i
    return :not_started if visited.zero?

    total = plan.all_location_count
    total.positive? && visited >= total ? :finished : :started
  end

  # Returns the appropriate back path based on where the user came from
  # If the user came from the homepage, return root_path
  # Otherwise, return explore_path
  def smart_back_path
    referrer = request.referrer
    if referrer.present? && URI.parse(referrer).path == "/"
      root_path
    else
      explore_path
    end
  rescue URI::InvalidURIError
    explore_path
  end

  # Returns translations for travel-profile Stimulus controller as JSON
  # This is used to pass I18n translations to JavaScript
  def travel_profile_translations_json
    {
      checking_location: t("travel_profile.checking_location"),
      visit_recorded: t("travel_profile.visit_recorded"),
      removed_from_favorites: t("travel_profile.removed_from_favorites"),
      added_to_favorites: t("travel_profile.added_to_favorites"),
      too_far_from_location: t("travel_profile.too_far_from_location", distance: "%{distance}", max_distance: "%{max_distance}"),
      location_no_coordinates: t("travel_profile.location_no_coordinates"),
      geolocation_not_supported: t("travel_profile.geolocation_not_supported"),
      geolocation_permission_denied: t("travel_profile.geolocation_permission_denied"),
      geolocation_unavailable: t("travel_profile.geolocation_unavailable"),
      geolocation_timeout: t("travel_profile.geolocation_timeout"),
      geolocation_error: t("travel_profile.geolocation_error"),
      validation_error: t("travel_profile.validation_error"),
      not_close_enough: t("travel_profile.not_close_enough"),
      sync_syncing: t("travel_profile.sync_syncing"),
      sync_saved: t("travel_profile.sync_saved"),
      sync_error: t("travel_profile.sync_error"),
      no_badges_yet: t("travel_profile.no_badges_yet"),
      no_recent_items: t("travel_profile.no_recent_items"),
      no_visited_locations: t("travel_profile.no_visited_locations"),
      no_favorite_locations: t("travel_profile.no_favorite_locations"),
      new_badge: t("travel_profile.new_badge"),
      badge_awesome: t("travel_profile.badge_awesome"),
      profile_exported: t("travel_profile.profile_exported"),
      profile_imported: t("travel_profile.profile_imported"),
      profile_import_error: t("travel_profile.profile_import_error"),
      profile_cleared: t("travel_profile.profile_cleared"),
      confirm_clear: t("travel_profile.confirm_clear"),
      confirm_replace_or_merge: t("travel_profile.confirm_replace_or_merge"),
      show_more: t("travel_profile.show_more", count: "%{count}"),
      time_just_now: t("travel_profile.time_just_now"),
      time_minutes_ago: t("travel_profile.time_minutes_ago", count: "%{count}"),
      time_hours_ago: t("travel_profile.time_hours_ago", count: "%{count}"),
      time_days_ago: t("travel_profile.time_days_ago", count: "%{count}"),
      badges: {
        first_visit: { name: t("travel_profile.badges.first_visit.name"), description: t("travel_profile.badges.first_visit.description") },
        explorer_5: { name: t("travel_profile.badges.explorer_5.name"), description: t("travel_profile.badges.explorer_5.description") },
        explorer_10: { name: t("travel_profile.badges.explorer_10.name"), description: t("travel_profile.badges.explorer_10.description") },
        explorer_25: { name: t("travel_profile.badges.explorer_25.name"), description: t("travel_profile.badges.explorer_25.description") },
        culture_lover: { name: t("travel_profile.badges.culture_lover.name"), description: t("travel_profile.badges.culture_lover.description") },
        foodie: { name: t("travel_profile.badges.foodie.name"), description: t("travel_profile.badges.foodie.description") },
        nature_lover: { name: t("travel_profile.badges.nature_lover.name"), description: t("travel_profile.badges.nature_lover.description") },
        city_hopper: { name: t("travel_profile.badges.city_hopper.name"), description: t("travel_profile.badges.city_hopper.description") },
        all_seasons: { name: t("travel_profile.badges.all_seasons.name"), description: t("travel_profile.badges.all_seasons.description") },
        collector: { name: t("travel_profile.badges.collector.name"), description: t("travel_profile.badges.collector.description") }
      }
    }.to_json
  end

  # Open Graph meta tags helper for social media previews
  # @param title [String] The page title
  # @param description [String] The page description (will be truncated to 200 chars)
  # @param image_url [String, nil] The URL for the preview image
  # @param type [String] The OG type (default: "website")
  # @param url [String, nil] The canonical URL (defaults to current request URL)
  # @return [String] HTML meta tags for Open Graph and Twitter Cards
  def og_meta_tags(title:, description:, image_url: nil, type: "website", url: nil)
    # Sanitize and truncate description
    clean_description = strip_tags(description.to_s).squish.truncate(200)
    page_url = url || request.original_url
    site_name = "Usput.ba"

    # Default image if none provided
    default_image_url = "#{request.protocol}#{request.host_with_port}/pwa-icon-512.png"
    final_image_url = image_url.presence || default_image_url

    tags = []

    # Open Graph tags
    tags << tag.meta(property: "og:title", content: title)
    tags << tag.meta(property: "og:description", content: clean_description)
    tags << tag.meta(property: "og:type", content: type)
    tags << tag.meta(property: "og:url", content: page_url)
    tags << tag.meta(property: "og:site_name", content: site_name)
    tags << tag.meta(property: "og:image", content: final_image_url)
    tags << tag.meta(property: "og:locale", content: I18n.locale == :bs ? "bs_BA" : "en_US")

    # Twitter Card tags
    tags << tag.meta(name: "twitter:card", content: "summary_large_image")
    tags << tag.meta(name: "twitter:title", content: title)
    tags << tag.meta(name: "twitter:description", content: clean_description)
    tags << tag.meta(name: "twitter:image", content: final_image_url)

    safe_join(tags, "\n")
  end

  # Default OG meta tags for pages without specific content
  def default_og_meta_tags
    og_meta_tags(
      title: "Usput.ba - Experience Bosnia & Herzegovina",
      description: t("app.description", default: "Discover hidden gems, authentic experiences and unforgettable places in Bosnia and Herzegovina")
    )
  end

  # Returns a random hero background image path from the hero_backgrounds folder
  # If no images are found, returns nil
  def random_hero_background
    backgrounds_path = Rails.root.join("app/assets/images/hero_backgrounds")
    image_extensions = %w[jpg jpeg png webp]

    # Find all image files in the hero_backgrounds folder
    image_files = Dir.glob(backgrounds_path.join("*.{#{image_extensions.join(',')}}"))

    return nil if image_files.empty?

    # Get just the filename from the randomly selected path
    selected_file = File.basename(image_files.sample)

    # Return the asset path for use in image_tag or CSS
    "hero_backgrounds/#{selected_file}"
  end
end

# frozen_string_literal: true

module MomentsHelper
  # Travels with the markup so swiping costs no request.
  def moment_caption_data(moment, download_url:, scope:, owned: false)
    data = {
      # The tile is what a shared link addresses, so it carries the id.
      moment_id: moment.public_id,
      moment_author: t("explore.moment_by", user: moment.user.username),
      moment_place: moment.location.name,
      moment_place_url: location_path(moment.location),
      moment_note: moment.note.presence,
      moment_uploaded: moment_uploaded_at(moment),
      moment_download_url: download_url,
      moment_owned: owned.to_s
    }

    # Two different things that happen to be the same url. The address is what the
    # viewer puts in the bar, and a private moment has one because its owner can
    # open it; the share link is only offered where a stranger following it finds
    # the moment.
    data[:moment_page_url] = moment_url(moment) if moment.shareable? || owned
    data[:moment_share_url] = moment_url(moment) if moment.shareable?

    data.merge!(like_data(moment, scope)) if moment.likeable?
    data.merge!(visibility_data(moment)) if owned
    { data: data.compact }
  end

  # created_at, not taken_at: a traveller can upload a photo from years ago.
  def moment_uploaded_at(moment)
    l(moment.created_at.to_date, format: :long)
  end

  private

  # The scope rides the url: the response rewrites the band it was pressed in,
  # and a moment can be in two of them.
  def like_data(moment, scope)
    return guest_like_data(moment) unless logged_in?

    {
      moment_like_url: moment_like_path(moment, context: scope),
      moment_liked: liked_moment?(moment).to_s,
      moment_likes_count: moment.likes_count
    }
  end

  # sessions#new keeps return_to, and both signing in and registering honour it.
  def guest_like_data(moment)
    {
      moment_like_url: login_path(return_to: request.fullpath),
      moment_like_guest: "true",
      moment_liked: "false",
      moment_likes_count: moment.likes_count
    }
  end

  public

  # Memoized like visited_location_ids: a grid of cards costs one query, not one each.
  def liked_moment_ids
    @liked_moment_ids ||= if logged_in?
      current_user.likes.where(likeable_type: "Moment").pluck(:likeable_id).to_set
    else
      Set.new
    end
  end

  def liked_moment?(moment)
    liked_moment_ids.include?(moment.id)
  end

  private

  def visibility_data(moment)
    private_now = moment.visibility_private_moment?

    {
      moment_visibility_url: private_now ? publish_plan_moment_path(moment.plan, moment)
                                         : unpublish_plan_moment_path(moment.plan, moment),
      moment_visibility_label: private_now ? t("plans.start.story_publish")
                                           : t("plans.moments.make_private"),
      moment_delete_url: plan_moment_path(moment.plan, moment),
      moment_note_url: plan_moment_path(moment.plan, moment)
    }
  end
end

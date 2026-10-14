# Turns what Google says about a person into a usput account: the one already
# linked to that Google account, or the one with the same email, or a new one.
# An email Google has not verified links to nothing, since anyone can type one.
class GoogleAccount
  PROVIDER = "google_oauth2"
  USERNAME_LENGTH = 24

  def initialize(auth)
    @auth = auth
  end

  def user
    linked_user || (email_verified? && link_by_email)
  end

  private

  attr_reader :auth

  def linked_user
    Identity.find_by(provider: PROVIDER, uid: uid)&.user
  end

  def link_by_email
    user = User.find_by(email: email) || new_user
    return if user.identities.exists?(provider: PROVIDER)

    user.identities.create!(provider: PROVIDER, uid: uid)
    take_over(user) unless user.confirmed?
    user
  end

  # An unconfirmed account was opened by whoever typed this email, and nobody
  # has proved they own it until now: Google just did. Whatever password that
  # stranger set, and any session they hold, must not survive the link.
  def take_over(user)
    user.password = Devise.friendly_token(32)
    user.confirm
    user.save!
    user.end_sessions
  end

  def new_user
    User.create!(username: available_username, email: email, password: Devise.friendly_token(32)) do |user|
      user.skip_confirmation!
    end
  end

  def available_username
    base = email.split("@").first.downcase.gsub(/[^a-z0-9_]/, "_").squeeze("_")[0, USERNAME_LENGTH]
    base = "traveller" if base.length < 3
    return base unless User.exists?(username: base)

    (2..).lazy.map { |n| "#{base}_#{n}" }.find { |name| !User.exists?(username: name) }
  end

  def uid
    auth.uid.to_s
  end

  def email
    auth.info.email.to_s.strip.downcase
  end

  def email_verified?
    email.present? && ActiveModel::Type::Boolean.new.cast(auth.info.email_verified)
  end
end

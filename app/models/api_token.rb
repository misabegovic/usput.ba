# frozen_string_literal: true

# A personal access token for the MCP server over HTTP. It carries its
# user's role and nothing more; usput keeps only its SHA-256 digest, so the
# token itself is shown once, when it is issued, and never again.
class APIToken < ApplicationRecord
  PREFIX = "usput_"

  belongs_to :user

  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true

  scope :live, -> { where(revoked_at: nil) }

  # Returns the record and the token, which exists only in this return value.
  def self.issue!(user:, name:)
    token = "#{PREFIX}#{SecureRandom.base58(40)}"
    [ create!(user:, name:, token_digest: digest(token)), token ]
  end

  # The live token's record, or nil, for a token as a caller presents it.
  def self.authenticate(token)
    return nil unless token.is_a?(String) && token.start_with?(PREFIX)

    live.includes(:user).find_by(token_digest: digest(token))
  end

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token)

  def revoke! = update!(revoked_at: Time.current)

  def revoked? = revoked_at.present?

  # At most once a minute, so a busy agent does not write on every call.
  def touch_used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end

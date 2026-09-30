# An outside account a traveller signs in with, such as Google.
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
end

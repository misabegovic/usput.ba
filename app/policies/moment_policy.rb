# Travellers publish moments; curators decide whether the public sees them.
# Only moments a traveller chose to make public reach the admin, and nobody
# creates, edits or deletes one there: rejecting is how a moment comes down.
class MomentPolicy < AdminPolicy
  def self.visible(query)
    query.visibility_public_moment
  end

  def show? = curator? && (record.nil? || record.visibility_public_moment?)
  def moderate? = show?
  def create? = false
  def update? = false
  def destroy? = false
end

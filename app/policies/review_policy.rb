# Travellers write reviews; Jev sorts them; curators decide the ones Jev held
# and may overturn any band. Nobody edits a traveller's words, and only an
# admin removes a review for good.
class ReviewPolicy < AdminPolicy
  def moderate? = curator?
  def create? = false
  def update? = false
end

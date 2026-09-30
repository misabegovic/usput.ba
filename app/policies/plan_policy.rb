# Curated plans (no traveller owns them) are the admin's to create and edit.
# Travellers' public plans can be looked at, so a curator can spot a problem,
# but never changed there; travellers' private plans never reach the admin.
class PlanPolicy < AdminPolicy
  def self.visible(query)
    query.where(user_id: nil).or(query.visibility_public_plan)
  end

  def show? = curator? && visible_record?
  def update? = curator? && curated?
  def destroy? = admin? && curated?

  private

  def curated? = record.nil? || record.user_id.nil?
  def visible_record? = record.nil? || record.user_id.nil? || record.visibility_public_plan?
end

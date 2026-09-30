# Users are the admin's alone. Nobody is created or deleted here: people sign
# up themselves, and account deletion is not decided yet. An admin never acts
# on their own account, so the last admin cannot lock everyone out.
class UserPolicy < AdminPolicy
  def index? = admin?
  def create? = false
  def update? = admin?
  def destroy? = false

  def change_role? = admin? && !own_account?
  def block? = admin? && !own_account? && !record&.blocked?
  def unblock? = admin? && record.present? && record.blocked?

  private

  def own_account? = record.present? && record == user
end

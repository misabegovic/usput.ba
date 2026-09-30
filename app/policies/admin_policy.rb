# What a role may do in the admin. Avo Community has no authorization of its
# own, so every Avo resource controller and action asks one of these, and the
# rules live in usput's code with tests (decisions: admin-through-avo).
#
# The default: curators and admins see, create and edit; only admins delete.
class AdminPolicy
  CONTROLLER_ACTIONS = {
    "index" => :index?, "show" => :show?,
    "new" => :create?, "create" => :create?,
    "edit" => :update?, "update" => :update?,
    "destroy" => :destroy?
  }.freeze

  def self.for(model_class)
    "#{model_class.name}Policy".safe_constantize || self
  end

  attr_reader :user, :record

  def initialize(user, record = nil)
    @user = user
    @record = record
  end

  def allows?(controller_action)
    query = CONTROLLER_ACTIONS[controller_action.to_s]
    query.present? && public_send(query)
  end

  def index? = curator?
  def show? = index?
  def create? = curator?
  def update? = curator?
  def destroy? = admin?

  private

  def curator? = user.present? && user.can_curate?
  def admin? = user.present? && user.admin?
end

class Avo::Resources::User < Avo::BaseResource
  self.icon = "tabler/outline/users"
  self.title = :username
  # URLs carry the public uuid (Identifiable#to_param), never the database id.
  self.find_record_method = -> { id.is_a?(Array) ? query.where(uuid: id) : query.find_by!(uuid: id) }
  self.search = {
    query: -> { query.where("username ILIKE :q OR email ILIKE :q", q: "%#{params[:q]}%") }
  }

  # Curators never see the users page in the menu; the controller refuses it too.
  def self.visible_on_sidebar
    UserPolicy.new(Avo::Current.user).index?
  end

  def fields
    field :username, as: :text, sortable: true
    field :email, as: :text, sortable: true
    field :user_type, as: :select, enum: ::User.user_types, name: I18n.t("admin.users.role"),
      readonly: true, sortable: true
    field :confirmed_at, as: :date_time, readonly: true, hide_on: :forms
    field :blocked_at, as: :date_time, readonly: true, hide_on: :forms
    field :created_at, as: :date_time, readonly: true, hide_on: :forms, sortable: true
  end

  def filters
    filter Avo::Filters::UserRole
    filter Avo::Filters::UserBlocked
  end

  def actions
    action Avo::Actions::ChangeRole
    action Avo::Actions::BlockUser
    action Avo::Actions::UnblockUser
  end
end

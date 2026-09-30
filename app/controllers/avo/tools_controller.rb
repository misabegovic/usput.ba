class Avo::ToolsController < Avo::ApplicationController
  def welcome
    @page_title = t("admin.welcome.title")
    add_breadcrumb title: @page_title
  end
end

# The policy gates on Avo's own controllers, which the per-resource gate
# (AdminResource) does not reach: associations, attachments and search.
Rails.application.config.to_prepare do
  {
    Avo::AssociationsController => AdminAssociationGate,
    Avo::AttachmentsController => AdminAttachmentGate,
    Avo::SearchController => AdminSearchGate
  }.each { |controller, gate| controller.include(gate) unless controller < gate }
end

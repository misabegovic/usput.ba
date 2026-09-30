# The policy gate on Avo's own associations controller (see AdminAssociationGate).
Rails.application.config.to_prepare do
  Avo::AssociationsController.include(AdminAssociationGate) unless Avo::AssociationsController < AdminAssociationGate
end

# frozen_string_literal: true

module Usput
  # Every command, in the order help lists them. The CLI and the MCP server
  # read this list; a command that is not here is offered by neither.
  module Commands
    def self.all
      [ PlacesList, PlacesShow, PlacesArchive, PlacesRestore,
        ExperiencesList, ExperiencesShow, PlansList, PlansShow, Search,
        MomentsQueue, MomentsApprove, MomentsReject,
        ReviewsQueue, ReviewsApprove, ReviewsReject, ReviewsJudge,
        History, Doctor ]
    end

    def self.find(name)
      all.find { |command| command.command_name == name || command.tool_name == name }
    end
  end
end

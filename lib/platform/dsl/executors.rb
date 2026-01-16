# frozen_string_literal: true

# Autoload executors
module Platform
  module DSL
    module Executors
      autoload :Schema, "platform/dsl/executors/schema"
      autoload :TableQuery, "platform/dsl/executors/table_query"
      autoload :Infrastructure, "platform/dsl/executors/infrastructure"
      autoload :Prompts, "platform/dsl/executors/prompts"
    end
  end
end

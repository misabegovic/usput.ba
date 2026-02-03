# frozen_string_literal: true

# Autoload executors
module Platform
  module DSL
    module Executors
      # Core executors (originally active)
      autoload :Schema, "platform/dsl/executors/schema"
      autoload :TableQuery, "platform/dsl/executors/table_query"
      autoload :Infrastructure, "platform/dsl/executors/infrastructure"

      # Restored executors (previously archived)
      autoload :Content, "platform/dsl/executors/content"
      autoload :Curator, "platform/dsl/executors/curator"
      autoload :External, "platform/dsl/executors/external"

      # Quality auditing
      autoload :Quality, "platform/dsl/executors/quality"
    end
  end
end

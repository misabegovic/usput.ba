# frozen_string_literal: true

# Helper for loading AI prompts from app/prompts/
#
# Prompts are stored as plain text files (.md, .txt) or ERB templates (.md.erb)
# This keeps prompts readable, versionable, and compatible with tools like Claude Code.
#
# Usage:
#   include PromptHelper
#
#   # Simple prompt (no interpolation)
#   prompt = load_prompt("experience_type_classifier/system.md")
#
#   # Prompt with variables (ERB)
#   prompt = load_prompt("location_enricher/metadata.md.erb",
#     location_name: "Stari Most",
#     city: "Mostar"
#   )
#
module PromptHelper
  PROMPTS_PATH = Rails.root.join("app/prompts")

  # Load a prompt from app/prompts/
  # @param path [String] Relative path to prompt file (e.g., "classifier/system.md")
  # @param vars [Hash] Variables for ERB interpolation
  # @return [String] Rendered prompt
  def load_prompt(path, **vars)
    full_path = PROMPTS_PATH.join(path)

    raise ArgumentError, "Prompt not found: #{path}" unless full_path.exist?

    template = full_path.read

    if path.end_with?(".erb")
      ERB.new(template).result_with_hash(vars)
    else
      template
    end
  end

  # List all available prompts
  # @return [Array<String>] List of prompt paths
  def available_prompts
    Dir.glob(PROMPTS_PATH.join("**/*.{md,txt,erb}")).map do |path|
      Pathname.new(path).relative_path_from(PROMPTS_PATH).to_s
    end.sort
  end
end

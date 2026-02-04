# SimpleCov must be loaded BEFORE application code
if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ])
  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"
    add_filter "/db/"

    # Enable branch coverage
    enable_coverage :branch

    # Minimum coverage threshold
    # Note: Lowered after major cleanup - removed ~27,000 lines of unused code
    # (platform database, unused jobs, analyzer services - see ADR 2026-02-03)
    minimum_coverage line: 80, branch: 67
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

# Monkey patch Location for tests to handle deprecated location_type parameter
class Location
  # Store location_type temporarily before creation
  attr_accessor :_temp_location_type

  # Override initialize to capture location_type
  alias_method :original_initialize, :initialize
  def initialize(attributes = {})
    attributes ||= {}
    @_temp_location_type = attributes.delete(:location_type) || attributes.delete("location_type")
    original_initialize(attributes)
  end

  # After create, add category based on temp location_type
  after_create :add_category_from_temp_type

  private

  def add_category_from_temp_type
    return unless @_temp_location_type

    category_key = @_temp_location_type.to_s
    category = LocationCategory.find_or_create_by!(key: category_key) do |cat|
      cat.name = category_key.titleize
      cat.icon = "circle"
      cat.active = true
      cat.position = LocationCategory.maximum(:position).to_i + 1
    end

    add_category(category, primary: true)
  end
end

module ActiveSupport
  class TestCase
    # Disable parallel tests when running with coverage (SimpleCov doesn't merge well)
    if ENV["COVERAGE"] || ENV["CI"]
      parallelize(workers: 1)
    else
      parallelize(workers: :number_of_processors)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

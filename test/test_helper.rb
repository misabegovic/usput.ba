# SimpleCov must be loaded BEFORE application code.
# Asked for by COVERAGE alone: CI sets CI for every step, and the system tests
# on their own cover far less than the threshold the unit suite is held to.
if ENV["COVERAGE"]
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

# Tests name a place's primary category as it is built: `test_category: :place`
# finds or creates that category and assigns it after create. The name is
# deliberately not a real attribute, so app code that writes a column Location
# does not have still fails here as it does in production.
class Location
  attr_accessor :_test_category

  alias_method :original_initialize, :initialize
  def initialize(attributes = {})
    attributes = (attributes || {}).dup
    @_test_category = attributes.delete(:test_category) || attributes.delete("test_category")
    original_initialize(attributes)
  end

  after_create :add_category_from_test_category

  private

  def add_category_from_test_category
    return unless @_test_category

    category_key = @_test_category.to_s
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

    # Mine Checker is fail-closed: without fresh mine data every BiH location
    # create/update is blocked. Point the static engine at synthetic
    # fresh-dated artifacts so ordinary tests keep working; mine-checker
    # tests install their own artifact sets. (docs/mine_checker/SPEC.md)
    setup do
      require_relative "support/static_artifacts"
      StaticArtifacts.use_default!
    end

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Asks the app, with a request of its own, whether this browser is signed in.
  def assert_signed_in(message = "expected the browser to be signed in")
    get user_plans_path, as: :json
    assert_response :success, message
  end

  def assert_signed_out(message = "expected the browser to be signed out")
    get user_plans_path, as: :json
    assert_response :unauthorized, message
  end
end

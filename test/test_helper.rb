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
    minimum_coverage line: 80, branch: 70
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

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

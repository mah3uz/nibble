ENV["RAILS_ENV"] ||= "test"
# Nibble's suite asserts against one site URL and the theme config/nibble.yml names, whatever a shell exports.
ENV["SITE_URL"] = "https://example.com"
ENV.delete("NIBBLE_THEME")
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/nibble_records_helper"
require_relative "test_helpers/nibble_starter_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

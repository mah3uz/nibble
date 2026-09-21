require "test_helper"

class SsrPortTest < ActiveSupport::TestCase
  VARIABLE = "INERTIA_SSR_PORT".freeze

  test "both ends of server rendering take the port from one setting, so a second instance can run beside the first" do
    assert_includes Rails.root.join("lib/nibble/frontend/ssr/ssr.ts").read, VARIABLE,
      "the SSR process must listen on the port #{VARIABLE} names"
    assert_includes Rails.root.join("config/initializers/inertia_rails.rb").read, VARIABLE,
      "Rails must look for the SSR process on the port #{VARIABLE} names"
  end

  test "an instance that sets nothing renders through 13714" do
    assert_equal "http://localhost:#{ENV.fetch(VARIABLE, 13714)}", InertiaRails.configuration.ssr_url
  end
end

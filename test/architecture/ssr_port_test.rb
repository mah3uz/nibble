require "test_helper"

class SsrPortTest < ActiveSupport::TestCase
  VARIABLE = "INERTIA_SSR_PORT".freeze

  test "both ends of server rendering take the port from one setting, so a second instance can run beside the first" do
    assert_includes Rails.root.join("vendor/nibble/frontend/ssr/ssr.ts").read, VARIABLE,
      "the SSR process must listen on the port #{VARIABLE} names"
    assert_includes Nibble::Install.templates_path.join("config/initializers/inertia_rails.rb").read, VARIABLE,
      "Rails must look for the SSR process on the port #{VARIABLE} names"
  end

  test "an instance that sets nothing renders through 13714" do
    assert_equal "http://localhost:#{ENV.fetch(VARIABLE, 13714)}", InertiaRails.configuration.ssr_url
  end

  test "while the Vite dev server runs, pages render through it rather than a bundle built for another theme" do
    original = InertiaRails::SSR.method(:vite_dev_server_url)
    InertiaRails::SSR.define_singleton_method(:vite_dev_server_url) { "http://localhost:3136" }

    url = InertiaRails::SSRRenderer.new(InertiaRails.configuration, page: {}).send(:url)

    assert_equal "http://localhost:3136/__inertia_ssr", url, "a built bundle is whatever theme last built it"
  ensure
    InertiaRails::SSR.define_singleton_method(:vite_dev_server_url, original)
  end
end

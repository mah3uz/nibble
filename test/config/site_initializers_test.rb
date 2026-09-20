require "test_helper"

class SiteInitializersTest < ActiveSupport::TestCase
  test "a site has somewhere of its own to run Ruby at boot" do
    initializer = Rails.application.initializers.find { |step| step.name == "nibble.site_initializers" }

    assert initializer, "without this a site has nowhere to subscribe to load hooks but our own config"
    assert_operator Rails.root.join("site/initializers"), :directory?
  end
end

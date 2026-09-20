require "test_helper"

class RoutesLayeringTest < ActiveSupport::TestCase
  ROUTE_FILES = [ "lib/nibble/routes/core.rb", "config/routes.rb", "lib/nibble/routes/catch_all.rb" ].freeze

  test "a site's routes are drawn between Nibble's fixed routes and its catch-all" do
    drawn = Rails.application.config.paths["config/routes.rb"].to_a
      .map { |path| Pathname(path).relative_path_from(Rails.root).to_s }

    assert_equal ROUTE_FILES, drawn
  end

  test "config/routes.rb belongs to the site, so Nibble draws none of its own routes there" do
    drawn = Rails.root.join("config/routes.rb").read[/draw do\n(.*)\nend/m, 1].to_s

    assert_empty drawn.strip, "Nibble's routes belong in lib/nibble/routes, or a site can't edit its own file safely"
  end

  test "the catch-all matches last, so neither the control panel nor a site's routes are swallowed" do
    specs = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
    catch_all = specs.index { |spec| spec.start_with?("/*path") }

    assert catch_all, "the catch-all must be drawn"
    assert_operator specs.index { |spec| spec.start_with?("/admin") }, :<, catch_all
    assert_operator specs.index { |spec| spec.start_with?("/api") }, :<, catch_all
  end
end

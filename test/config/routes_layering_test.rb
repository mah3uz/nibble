require "test_helper"

class RoutesLayeringTest < ActiveSupport::TestCase
  ROUTE_FILES = [ "vendor/nibble/config/routes/core.rb", "config/routes.rb", "vendor/nibble/config/routes/catch_all.rb" ].freeze

  test "a site's routes are drawn between Nibble's fixed routes and its catch-all" do
    drawn = Rails.application.routes_reloader.paths
      .map { |path| Pathname(path).relative_path_from(Rails.root).to_s }.select { |path| ROUTE_FILES.include?(path) }

    assert_equal ROUTE_FILES, drawn
  end

  NIBBLE_PATHS = [ "/forms/:handle", "/media/:uuid/:filename", "/robots.txt", "/sitemap.xml", "/*path" ].freeze

  test "config/routes.rb belongs to the site, so Nibble draws none of its own routes there" do
    drawn = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
    site = Rails.root.join("config/routes.rb").read[/draw do\n(.*)\nend/m, 1].to_s

    NIBBLE_PATHS.each do |path|
      assert_includes drawn, path, "#{path} is one of Nibble's fixed routes and has to stay drawn"
      refute_includes site, path.delete_prefix("/"),
        "#{path} is Nibble's, so it belongs in vendor/nibble/config/routes — a site has to own config/routes.rb outright"
    end
  end

  test "the catch-all matches last, so neither the Control Plane nor a site's routes are swallowed" do
    specs = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
    catch_all = specs.index { |spec| spec.start_with?("/*path") }

    assert catch_all, "the catch-all must be drawn"
    assert_operator specs.index { |spec| spec.start_with?("/cp") }, :<, catch_all
    assert_operator specs.index { |spec| spec.start_with?("/api") }, :<, catch_all
  end
end

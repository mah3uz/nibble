require "test_helper"

# The browser formats numbers and dates with this tag. It comes from the server so the server-rendered text
# and the browser's agree: the server cannot know the browser's locale, and each guessing would mismatch on hydration.
class Nibble::Cp::FormatLocaleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:editor)
    @config = Nibble.config
  end

  teardown { Nibble.config = @config }

  def format_locale(accept_language: nil)
    get cp_root_path, headers: accept_language ? { "Accept-Language" => accept_language } : {}
    JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]["cp"]["format_locale"]
  end

  test "the site's default locale wins over the browser's" do
    Nibble.config = Nibble::Config.new({ "theme" => @config.theme, "locales" => [ { "code" => "fr-CA", "default" => true } ] },
      themes_path: Rails.root.join("test/nibble_themes"))

    assert_equal "fr-CA", format_locale(accept_language: "de-DE,de;q=0.9")
  end

  test "a site with no locale uses the first tag of the request's Accept-Language" do
    Nibble.config = Nibble::Config.new({ "theme" => @config.theme }, themes_path: Rails.root.join("test/nibble_themes"))

    assert_equal "de-DE", format_locale(accept_language: "de-DE,de;q=0.9,en;q=0.8")
  end

  test "an unusable Accept-Language falls back to en" do
    Nibble.config = Nibble::Config.new({ "theme" => @config.theme }, themes_path: Rails.root.join("test/nibble_themes"))

    assert_equal "en", format_locale(accept_language: "<script>,en_US;;")
    assert_equal "en", format_locale(accept_language: "*")
    assert_equal "en", format_locale
  end
end

require "test_helper"

class NibbleIntegrationsTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup { seed_starter_site }

  def save_integrations(values)
    record = Nibble::Records::GlobalSet.find_or_initialize_by(handle: "integrations", locale: "en")
    ok Nibble::Lifecycle.call(record, :save, values)
  end

  def live
    original = Nibble::Seo.method(:indexable?)
    Nibble::Seo.define_singleton_method(:indexable?) { true }
    yield
  ensure
    Nibble::Seo.define_singleton_method(:indexable?, original)
  end

  def page_props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  test "analytics and custom code reach live pages, with IDs escaped and attributes limited to data-*" do
    save_integrations("ga4_measurement_id" => "G-ABC123", "gtm_container_id" => "GTM-XYZ9",
      "analytics_script_src" => "https://plausible.io/js/script.js",
      "analytics_script_attributes" => [ { "name" => "data-domain", "value" => "example.test\"><script>x</script>" } ],
      "head_code" => "<meta name=\"head-marker\">", "body_code" => "<div id=\"body-marker\"></div>")

    live { get "/blog/grids" }
    html = Nokogiri::HTML(response.body)
    assert html.at_css('script[src="https://www.googletagmanager.com/gtag/js?id=G-ABC123"]')
    assert_includes response.body, %('dataLayer',"GTM-XYZ9")
    assert html.at_css('noscript iframe[src="https://www.googletagmanager.com/ns.html?id=GTM-XYZ9"]')
    assert_equal "example.test\"><script>x</script>", html.at_css('script[src="https://plausible.io/js/script.js"]')["data-domain"]
    assert html.at_css('head meta[name="head-marker"]')
    assert html.at_css("body #body-marker")
  end

  test "nothing loads where the site isn't indexable, so staging and development never report analytics" do
    save_integrations("ga4_measurement_id" => "G-ABC123", "head_code" => "<meta name=\"head-marker\">")

    get "/blog/grids"
    assert_not_includes response.body, "G-ABC123"
    assert_not_includes response.body, "head-marker"
  end

  test "IDs that aren't Google's formats are refused, so they can't break out of the snippet" do
    record = Nibble::Records::GlobalSet.new(handle: "integrations", locale: "en")
    result = Nibble::Lifecycle.call(record, :save, { "ga4_measurement_id" => "G-1');alert(1)//" })
    assert result.invalid?
  end

  test "the CAPTCHA secret is encrypted at rest, masked for the CP and never sent to theme pages" do
    save_integrations("captcha_provider" => "turnstile", "captcha_site_key" => "site-key",
      "captcha_secret_key" => { "plain" => "top-secret" })

    stored = Nibble::Records::GlobalSet.find_by!(handle: "integrations").data["captcha_secret_key"]
    assert_not_includes stored, "top-secret"
    assert_equal({ "provider" => "turnstile", "site_key" => "site-key", "secret_key" => "top-secret", "min_score" => 0.5 }, Nibble::Integrations.captcha)

    field = Nibble::Records::GlobalSet.find_by!(handle: "integrations").blueprint_fields.get("captcha_secret_key")
    assert_equal({ "set" => true, "ciphertext" => stored }, field.fieldtype.pre_process(stored))
    assert_nil field.fieldtype.augment(stored)

    live { get "/blog/grids" }
    assert_not_includes response.body, "top-secret"
    assert_not_includes response.body, stored
    assert_not page_props["site"]["globals"].key?("integrations"), "theme pages don't carry the integration settings"
  end

  test "saving the CP form keeps the stored secret unless it's replaced or cleared" do
    save_integrations("captcha_secret_key" => { "plain" => "first" })
    stored = Nibble::Records::GlobalSet.find_by!(handle: "integrations").data["captcha_secret_key"]

    save_integrations("captcha_site_key" => "changed", "captcha_secret_key" => { "set" => true, "ciphertext" => stored })
    assert_equal "first", Nibble::Secrets.global("integrations", "captcha_secret_key")
    save_integrations("captcha_secret_key" => { "plain" => "second" })
    assert_equal "second", Nibble::Secrets.global("integrations", "captcha_secret_key")
    save_integrations("captcha_secret_key" => { "clear" => true })
    assert_nil Nibble::Secrets.global("integrations", "captcha_secret_key")
  end

  test "changing integrations clears cached pages, because every page's layout depends on them" do
    get "/blog/grids"
    assert_includes response.headers["Surrogate-Key"].split, "global:integrations"
  end
end

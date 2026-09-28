require "test_helper"

class NibbleIntegrationsTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup { seed_starter_site }

  def save_integrations(values)
    record = Nibble::Records::GlobalSet.find_or_initialize_by(handle: "integrations", locale: "en")
    ok Nibble::Lifecycle.call(record, :save, values, actor: Nibble::Principal.system)
  end

  def live
    original = Nibble::Seo.method(:indexable?)
    Nibble::Seo.define_singleton_method(:indexable?) { true }
    yield
  ensure
    Nibble::Seo.define_singleton_method(:indexable?, original)
  end

  def page_props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  def errors_for(values)
    record = Nibble::Records::GlobalSet.new(handle: "integrations", locale: "en")
    Nibble::Lifecycle.call(record, :save, values, actor: Nibble::Principal.system).errors
  end

  test "analytics cards and snippets reach live pages, each snippet in its place and order, paused ones left out" do
    save_integrations(
      "analytics" => [ { "type" => "plausible", "script_url" => "https://stats.example.com/js/pa-AbC123.js" },
        { "type" => "gtm", "container_id" => "GTM-XYZ9" } ],
      "custom_code" => [
        { "type" => "snippet", "name" => "Verify", "placement" => "head", "code" => %(<meta name="head-marker">) },
        { "type" => "snippet", "name" => "Chat", "placement" => "body_end", "code" => %(<div id="end-first"></div>) },
        { "type" => "snippet", "name" => "Banner", "placement" => "body_start", "code" => %(<div id="start-marker"></div>) },
        { "type" => "snippet", "name" => "Old", "placement" => "head", "code" => %(<meta name="paused">), "enabled" => false },
        { "type" => "snippet", "name" => "Widget", "placement" => "body_end", "code" => %(<div id="end-second"></div>) }
      ])

    live { get "/blog/grids" }
    html = Nokogiri::HTML(response.body)
    assert html.at_css('head script[src="https://stats.example.com/js/pa-AbC123.js"]')
    assert_includes html.at_css("head").to_html, "plausible.init()"
    assert html.at_css('head meta[name="head-marker"]')
    assert_nil html.at_css('meta[name="paused"]')
    body = html.at_css("body").element_children
    assert_equal "noscript", body.first.name, "GTM's frame opens the body"
    assert_equal "start-marker", body[1]["id"]
    assert_equal %w[end-first end-second], body.to_a.last(2).map { |node| node["id"] }
  end

  test "nothing loads where the site isn't indexable, so staging and development never report analytics" do
    save_integrations("analytics" => [ { "type" => "ga4", "measurement_id" => "G-ABC123" } ],
      "custom_code" => [ { "type" => "snippet", "name" => "Verify", "placement" => "head", "code" => %(<meta name="head-marker">) } ])

    get "/blog/grids"
    assert_not_includes response.body, "G-ABC123"
    assert_not_includes response.body, "head-marker"
  end

  test "an ID in the wrong shape is refused with the shape it should have, so it can't break out of the snippet" do
    errors = errors_for("analytics" => [ { "type" => "ga4", "measurement_id" => "G-1');alert(1)//" } ])
    assert_equal [ "That isn't a GA4 measurement ID; it looks like G-XXXXXXXXXX." ], errors["analytics.0.measurement_id"]
  end

  test "Plausible's older script.js needs a domain, and the pa- script doesn't ask for one" do
    assert errors_for("analytics" => [ { "type" => "plausible", "script_url" => "https://plausible.io/js/script.js" } ]).key?("analytics.0.domain")
    assert_empty errors_for("analytics" => [ { "type" => "plausible", "script_url" => "https://plausible.io/js/pa-AbC123.js" } ])
  end

  test "Cloudflare can't be added twice, because a page carries one beacon" do
    card = { "type" => "cloudflare", "token" => "0123456789abcdef0123456789abcdef" }
    assert errors_for("analytics" => [ card, card ]).key?("analytics")
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

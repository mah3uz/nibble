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

  test "a vendor's snippet reaches live pages exactly as pasted, where the vendor says, with custom code in its places" do
    plausible = %(<script async src="https://stats.example.com/js/pa-AbC123.js"></script>\n<script>plausible.init()</script>)
    save_integrations(
      "analytics" => [ { "type" => "plausible", "head" => plausible },
        { "type" => "gtm", "head" => "<script>gtm()</script>", "body_start" => %(<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-XYZ9"></iframe></noscript>) },
        { "type" => "cloudflare", "body_end" => %(<script defer src="https://static.cloudflareinsights.com/beacon.min.js"></script>) } ],
      "custom_code" => [
        { "type" => "snippet", "name" => "Verify", "placement" => "head", "code" => %(<meta name="head-marker">) },
        { "type" => "snippet", "name" => "Chat", "placement" => "body_end", "code" => %(<div id="end-first"></div>) },
        { "type" => "snippet", "name" => "Banner", "placement" => "body_start", "code" => %(<div id="start-marker"></div>) },
        { "type" => "snippet", "name" => "Old", "placement" => "head", "code" => %(<meta name="paused">), "enabled" => false },
        { "type" => "snippet", "name" => "Widget", "placement" => "body_end", "code" => %(<div id="end-second"></div>) }
      ])

    live { get "/blog/grids" }
    assert_includes response.body, plausible, "the snippet is written as the vendor gave it"
    html = Nokogiri::HTML(response.body)
    assert html.at_css('head meta[name="head-marker"]')
    assert_nil html.at_css('meta[name="paused"]')
    body = html.at_css("body").element_children
    assert_equal "noscript", body.first.name, "Tag Manager's frame opens the body"
    assert_equal "start-marker", body[1]["id"]
    assert_equal [ "static.cloudflareinsights.com", "end-first", "end-second" ],
      body.to_a.last(3).map { |node| node["src"].to_s[%r{//([^/]+)}, 1] || node["id"] }, "Cloudflare's beacon closes the page, before custom code"
  end

  test "nothing loads where the site isn't indexable, so staging and development never report analytics" do
    save_integrations("analytics" => [ { "type" => "ga4", "head" => "<script>gtag('config', 'G-ABC123')</script>" } ],
      "custom_code" => [ { "type" => "snippet", "name" => "Verify", "placement" => "head", "code" => %(<meta name="head-marker">) } ])

    get "/blog/grids"
    assert_not_includes response.body, "G-ABC123"
    assert_not_includes response.body, "head-marker"
  end

  test "a card refuses what isn't a snippet, such as a pasted ID, so a mistake is caught on save" do
    errors = errors_for("analytics" => [ { "type" => "ga4", "head" => "G-ABC123" } ])
    assert_match "exactly as the vendor gives it", errors["analytics.0.head"].sole
  end

  test "Cloudflare can't be added twice, because a page carries one beacon" do
    card = { "type" => "cloudflare", "body_end" => "<script>beacon()</script>" }
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

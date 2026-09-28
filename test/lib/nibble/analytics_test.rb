require "test_helper"

class Nibble::AnalyticsTest < ActiveSupport::TestCase
  def tags(*cards, place: :head) = Nibble::Analytics.render(cards).tags.fetch(place)
  def doc(*cards, place: :head) = Nokogiri::HTML.fragment(tags(*cards, place:).join("\n"))

  test "Plausible's pa- script is started by the inline init, which a script tag alone never runs" do
    html = tags({ "type" => "plausible", "script_url" => "https://stats.example.com/js/pa-AbC123.js" })

    assert_equal [ %(<script async src="https://stats.example.com/js/pa-AbC123.js"></script>), Nibble::Analytics::PLAUSIBLE_INIT ], html
    assert_includes Nibble::Analytics::PLAUSIBLE_INIT, "plausible.init()"
  end

  test "Plausible's older script.js is written with its domain, and not at all without one" do
    script = doc({ "type" => "plausible", "script_url" => "https://plausible.io/js/script.outbound-links.js", "domain" => "example.com" }).at_css("script")
    assert_equal "example.com", script["data-domain"]
    assert script.key?("defer")
    assert_not_includes script.to_html, "plausible.init"

    assert_empty tags({ "type" => "plausible", "script_url" => "https://plausible.io/js/script.js" })
  end

  test "several GA4 cards share one gtag.js and each configures its own ID" do
    html = tags({ "type" => "ga4", "measurement_id" => "G-AAA111" }, { "type" => "ga4", "measurement_id" => "G-BBB222" }).join("\n")

    assert_equal 1, html.scan("googletagmanager.com/gtag/js").size
    assert_equal 1, html.scan("gtag('js'").size
    assert_includes html, %(gtag('config',"G-AAA111"))
    assert_includes html, %(gtag('config',"G-BBB222"))
  end

  test "Tag Manager's noscript frame opens the body, where Google says it goes" do
    card = { "type" => "gtm", "container_id" => "GTM-XYZ9" }

    assert_includes tags(card).join, %('dataLayer',"GTM-XYZ9")
    assert doc(card, place: :body_start).at_css('noscript iframe[src="https://www.googletagmanager.com/ns.html?id=GTM-XYZ9"]')
    assert_empty tags(card, place: :body_end)
  end

  test "Fathom and Cloudflare are told to count page changes, which the public site makes without a reload" do
    fathom = doc({ "type" => "fathom", "site_id" => "ABCDEFGH" }).at_css('script[src="https://cdn.usefathom.com/script.js"]')
    assert_equal [ "ABCDEFGH", "auto" ], [ fathom["data-site"], fathom["data-spa"] ]

    beacon = doc({ "type" => "cloudflare", "token" => "0123456789abcdef0123456789abcdef" }).at_css('script[src="https://static.cloudflareinsights.com/beacon.min.js"]')
    assert_equal({ "token" => "0123456789abcdef0123456789abcdef", "spa" => true }, JSON.parse(beacon["data-cf-beacon"]))
  end

  test "Umami uses Umami Cloud's script unless a self-hosted one is given" do
    id = "94db1cb1-74f4-4a40-ad6c-962362670409"

    assert doc({ "type" => "umami", "website_id" => id }).at_css(%(script[src="https://cloud.umami.is/script.js"][data-website-id="#{id}"][defer]))
    assert doc({ "type" => "umami", "website_id" => id, "script_url" => "https://umami.example.com/script.js" }).at_css('script[src="https://umami.example.com/script.js"]')
  end

  test "the script tag keeps only data- attributes and escapes their values" do
    script = doc({ "type" => "script", "script_url" => "https://example.com/a.js",
      "attributes" => [ { "name" => "data-x", "value" => %(1"><script>alert(1)</script>) }, { "name" => "onload", "value" => "alert(1)" } ] }).at_css("script")

    assert_equal %(1"><script>alert(1)</script>), script["data-x"]
    assert_nil script["onload"]
  end

  test "a value that got past validation writes nothing, so it can never break out of a tag" do
    hostile = [
      { "type" => "ga4", "measurement_id" => %(G-1"><script>alert(1)</script>) },
      { "type" => "gtm", "container_id" => "GTM-1');alert(1)//" },
      { "type" => "fathom", "site_id" => %(A" onload="alert(1)) },
      { "type" => "plausible", "script_url" => "javascript:alert(1)" },
      { "type" => "script", "script_url" => %(https://x.test/a.js"><script>alert(1)</script>) }
    ]

    Nibble::Analytics::Page::PLACES.each { |place| assert_empty tags(*hostile, place:), place }
  end

  test "a paused card writes nothing, so it can be switched off without losing its settings" do
    assert_empty tags({ "type" => "ga4", "measurement_id" => "G-ABC123", "enabled" => false })
  end

  test "Cloudflare's beacon is written once, since a page may carry only one" do
    token = "0123456789abcdef0123456789abcdef"
    assert_equal 1, tags({ "type" => "cloudflare", "token" => token }, { "type" => "cloudflare", "token" => token }).size
  end

  test "a site can add a tool of its own, and an unknown card writes nothing" do
    Nibble::Analytics.register("pirsch") { |card, page| page.add(:head, %(<meta name="pirsch" content="#{Nibble::Analytics.h(card['code'])}">)) }

    assert_equal [ %(<meta name="pirsch" content="abc">) ], tags({ "type" => "pirsch", "code" => "abc" })
    assert_empty tags({ "type" => "nobody" })
  ensure
    Nibble::Analytics.renderers.delete("pirsch")
  end

  test "IDs are refused with the shape they should have" do
    assert_equal "That isn't a GA4 measurement ID; it looks like G-XXXXXXXXXX.", Nibble::Analytics.format_error("ga4", "UA-1234")
    assert_nil Nibble::Analytics.format_error("ga4", "G-ABC123")
  end
end

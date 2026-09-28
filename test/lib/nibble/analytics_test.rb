require "test_helper"

class Nibble::AnalyticsTest < ActiveSupport::TestCase
  # As each vendor's dashboard hands them out, so a card takes what people actually copy.
  VENDOR_SNIPPETS = {
    "Plausible" => <<~HTML,
      <script async src="https://plausible.io/js/pa-Xgk06lKB1COZvDqnhUH65.js"></script>
      <script>
        window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(i){plausible.o=i||{}};
        plausible.init()
      </script>
    HTML
    "Fathom" => %(<script src="https://cdn.usefathom.com/script.js" data-site="ABCDEFGH" defer></script>),
    "Umami" => %(<script defer src="https://cloud.umami.is/script.js" data-website-id="94db1cb1-74f4-4a40-ad6c-962362670409"></script>),
    "Cloudflare" => %(<!-- Cloudflare Web Analytics --><script defer src='https://static.cloudflareinsights.com/beacon.min.js' data-cf-beacon='{"token": "0123456789abcdef"}'></script><!-- End Cloudflare Web Analytics -->),
    "Google tag" => <<~HTML,
      <!-- Google tag (gtag.js) -->
      <script async src="https://www.googletagmanager.com/gtag/js?id=G-ABC123"></script>
      <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());

        gtag('config', 'G-ABC123');
      </script>
    HTML
    "Tag Manager body" => <<~HTML
      <!-- Google Tag Manager (noscript) -->
      <noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-XYZ9"
      height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
      <!-- End Google Tag Manager (noscript) -->
    HTML
  }.freeze

  test "every vendor's snippet is accepted as the vendor gives it" do
    VENDOR_SNIPPETS.each { |vendor, snippet| assert_nil Nibble::Analytics.snippet_problem(snippet), vendor }
  end

  test "anything that isn't a snippet is refused, so a pasted ID or stray markup is caught before it reaches a page" do
    [ "G-ABC123", "https://plausible.io/js/pa-x.js", %(<div>Chat</div>), %(<img src=x onerror="alert(1)">),
      %(<script src="https://a.test/x.js"></script><p>after</p>), "" ].each do |paste|
      assert Nibble::Analytics.snippet_problem(paste), paste
    end
  end

  test "each card's snippet goes where its field says, in card order, and a paused card writes nothing" do
    cards = [
      { "type" => "plausible", "head" => "<script>one()</script>" },
      { "type" => "gtm", "head" => "<script>two()</script>", "body_start" => "<noscript>fallback</noscript>" },
      { "type" => "fathom", "head" => "<script>paused()</script>", "enabled" => false },
      { "type" => "cloudflare", "body_end" => "<script>beacon()</script>" }
    ]

    assert_equal [ "<script>one()</script>", "<script>two()</script>" ], Nibble::Analytics.html(cards, :head)
    assert_equal [ "<noscript>fallback</noscript>" ], Nibble::Analytics.html(cards, :body_start)
    assert_equal [ "<script>beacon()</script>" ], Nibble::Analytics.html(cards, :body_end)
  end
end

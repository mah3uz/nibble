require "test_helper"
require "webmock"

class Nibble::OutboundTest < ActiveSupport::TestCase
  include WebMock::API

  Outbound = Nibble::Outbound
  DNS = {
    "api.example.test" => [ "93.184.216.34" ],
    "internal.example.test" => [ "10.0.0.5" ],
    "mixed.example.test" => [ "93.184.216.34", "127.0.0.1" ],
    "metadata.example.test" => [ "169.254.169.254" ],
    "v6.example.test" => [ "2606:4700::1111" ],
    "mapped.example.test" => [ "::ffff:127.0.0.1" ]
  }.freeze

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
    @resolver = Outbound::Guard.resolver
    Outbound::Guard.resolver = ->(host) { DNS.fetch(host, []) }
  end

  teardown do
    Outbound::Guard.resolver = @resolver
    WebMock.reset!
    WebMock.disable!
    Nibble.config = nil
    ENV.delete("NIBBLE_SECRET_CRM_TOKEN")
  end

  def configure(outbound)
    Nibble.config = Nibble::Config.new({ "locales" => [ { "code" => "en", "default" => true } ], "outbound" => outbound })
  end

  def refused(url, method: :get)
    assert_raises(Outbound::Refused) { Outbound.request(method, url, purpose: "test") }
  end

  test "private, loopback, link-local, CGNAT, metadata and reserved addresses are all blocked, in IPv4 and IPv6" do
    %w[
      127.0.0.1 10.1.2.3 172.20.0.1 192.168.1.1 169.254.169.254 100.64.0.1 0.0.0.0 224.0.0.1 255.255.255.255 198.18.0.1
      ::1 :: fe80::1 fc00::1 fd12:3456::1 ff02::1 ::ffff:127.0.0.1 ::ffff:169.254.169.254 64:ff9b::a9fe:a9fe 2002:7f00:1:: 2001:db8::1
    ].each { |address| assert Outbound::Guard.blocked_ip?(address), "#{address} must be blocked" }
    %w[93.184.216.34 1.1.1.1 2606:4700::1111].each { |address| assert_not Outbound::Guard.blocked_ip?(address), "#{address} is public" }
  end

  test "literal internal addresses and the cloud metadata endpoint are refused before any connection" do
    %w[http://127.0.0.1/ http://[::1]/admin http://169.254.169.254/latest/meta-data http://10.0.0.1:8080/ http://[::ffff:7f00:1]/].each { |url| refused(url) }
    assert_not_requested :any, /.*/
  end

  test "odd IPv4 spellings never reach a connection, whether the resolver ignores them or reads them as libc does" do
    urls = %w[http://2130706433/ http://0x7f000001/ http://017700000001/ http://127.1/ http://0177.0.0.1/]
    urls.each { |url| refused(url) }

    Outbound::Guard.resolver = ->(host) { Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq }
    urls.each do |url|
      assert_raises(Outbound::Refused, match: /private or reserved/) { Outbound.request(:get, url, purpose: "test") }
    end
    assert_not_requested :any, /.*/
  end

  test "a hostname whose DNS answer points inside is refused, even when only one of its answers does" do
    %w[http://internal.example.test/ http://mixed.example.test/ http://metadata.example.test/ http://mapped.example.test/].each { |url| refused(url) }
    assert_equal "93.184.216.34", Outbound::Guard.check!(URI("https://api.example.test/")), "the connection is pinned to the checked address"
  end

  test "redirects are re-checked, so a public URL can't bounce the request inward" do
    stub_request(:get, "https://api.example.test/start").to_return(status: 302, headers: { "Location" => "http://internal.example.test/secrets" })
    stub_request(:get, "https://api.example.test/meta").to_return(status: 307, headers: { "Location" => "http://169.254.169.254/latest" })

    refused("https://api.example.test/start")
    refused("https://api.example.test/meta")
    assert_not_requested :get, "http://internal.example.test/secrets"
  end

  test "a 303 after a POST follows as a GET without the body, and redirect loops stop" do
    stub_request(:post, "https://api.example.test/submit").to_return(status: 303, headers: { "Location" => "/done" })
    stub_request(:get, "https://api.example.test/done").to_return(status: 200, body: "ok")
    stub_request(:get, "https://api.example.test/loop").to_return(status: 302, headers: { "Location" => "/loop" })

    response = Outbound.request(:post, "https://api.example.test/submit", purpose: "test", body: { "a" => 1 })
    assert_equal [ 200, "ok" ], [ response.status, response.body ]
    assert_requested(:get, "https://api.example.test/done") { |request| request.body.blank? }
    refused("https://api.example.test/loop")
  end

  test "only http and https are allowed, and an allowlist narrows public hosts when set" do
    %w[file:///etc/passwd ftp://api.example.test/ gopher://api.example.test/].each { |url| refused(url) }

    configure("allowed_hosts" => [ "*.partner.test" ])
    refused("https://api.example.test/")
  end

  test "oversized and slow responses fail instead of tying up a worker" do
    stub_request(:get, "https://api.example.test/big").to_return(status: 200, body: "x" * 2.megabytes)
    stub_request(:get, "https://api.example.test/slow").to_timeout

    assert_raises(Outbound::Failed, match: /larger than/) { Outbound.request(:get, "https://api.example.test/big", purpose: "test") }
    assert_raises(Outbound::Failed) { Outbound.request(:get, "https://api.example.test/slow", purpose: "test") }
    assert_equal 2, Nibble::Records::OutboundRequest.where.not(error: nil).count, "failures are logged too"
  end

  test "every call is logged against its owner with secrets and credential headers redacted" do
    configure("secrets" => [ "crm_token" ], "config" => { "region" => "au" })
    ENV["NIBBLE_SECRET_CRM_TOKEN"] = "s3cr3t-value"
    stub_request(:post, "https://api.example.test/leads?token=s3cr3t-value").to_return(status: 201, body: '{"echo":"s3cr3t-value"}')
    owner = Nibble::Records::FormSubmission.create!(form: "contact")

    template = Outbound::Template.new(fields: { "email" => "a@example.test", "count" => 3 })
    body = template.render({ "email" => "{field.email}", "count" => "{field.count}", "region" => "{config.region}", "note" => "key {secret.crm_token}" })
    assert_equal({ "email" => "a@example.test", "count" => 3, "region" => "au", "note" => "key s3cr3t-value" }, body)

    Outbound.request(:post, template.render("https://api.example.test/leads?token={secret.crm_token}"), purpose: "form", owner:, body:,
      headers: { "Authorization" => "Bearer s3cr3t-value" }, secrets: template.secrets_used)

    log = Nibble::Records::OutboundRequest.sole
    assert_equal [ owner, 201, "form" ], [ log.owner, log.status, log.purpose ]
    [ log.url, log.request_body, log.response_body, log.request_headers.to_json ].each { |text| assert_not_includes text, "s3cr3t-value" }
    assert_equal "[redacted]", log.request_headers["Authorization"]
  end

  test "only secrets named in outbound.secrets can be read, so a schema file can't pull arbitrary credentials" do
    configure("secrets" => [])
    ENV["NIBBLE_SECRET_CRM_TOKEN"] = "s3cr3t-value"

    assert_raises(Nibble::Error, match: /isn't listed/) { Outbound::Template.new.render("{secret.crm_token}") }
  end
end

require "test_helper"

class Nibble::Cp::ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]

  test "only people who manage tokens can see or mint them" do
    sign_in_as users(:editor)

    get "/cp/api-tokens"
    assert_response :forbidden

    post "/cp/api-tokens", params: { api_token: { name: "Sneak", scopes: %w[read] } }
    assert_response :forbidden
    assert_equal 0, Nibble::ApiToken.count
  end

  test "a new token is shown once and afterwards only its prefix is left" do
    post "/cp/api-tokens", params: { api_token: { name: "Marketing site", scopes: %w[read], expires_in: "90" } }

    get "/cp/api-tokens"
    issued = props["issued"]
    assert_match(/\Anib_[0-9a-f]{48}\z/, issued["token"])
    assert_equal Nibble::ApiToken.sole.prefix, issued["token"].first(11)
    assert_not_includes Nibble::ApiToken.sole.attributes.values, issued["token"], "the plain token is never stored"

    get "/cp/api-tokens"
    assert_nil props["issued"], "it's shown once, not on every visit"
  end

  test "a token authenticates by its digest, and a revoked or expired one doesn't" do
    _, plaintext = Nibble::ApiToken.issue(name: "Live", scopes: %w[read])

    assert_equal "Live", Nibble::ApiToken.authenticate(plaintext).name
    assert_nil Nibble::ApiToken.authenticate("nib_#{'0' * 48}")

    Nibble::ApiToken.sole.update!(revoked_at: Time.current)
    assert_nil Nibble::ApiToken.authenticate(plaintext)

    Nibble::ApiToken.sole.update!(revoked_at: nil, expires_at: 1.minute.ago)
    assert_nil Nibble::ApiToken.authenticate(plaintext)
  end

  test "a preview token may also read live content, but a read token can't see drafts" do
    _, preview = Nibble::ApiToken.issue(name: "Preview", scopes: %w[preview])
    _, read = Nibble::ApiToken.issue(name: "Read", scopes: %w[read])

    assert Nibble::ApiToken.authenticate(preview).allows?("read")
    assert Nibble::ApiToken.authenticate(preview).allows?("preview")
    assert Nibble::ApiToken.authenticate(read).allows?("read")
    assert_not Nibble::ApiToken.authenticate(read).allows?("preview")
  end

  test "a scope that doesn't exist is refused, so a typo can't quietly grant nothing" do
    post "/cp/api-tokens", params: { api_token: { name: "Typo", scopes: %w[read manage:nowhere] } }

    assert_equal 0, Nibble::ApiToken.count
    get "/cp/api-tokens"
    assert_equal 0, props["tokens"].size
  end

  test "revoking a token keeps the record, so the audit trail stays" do
    token, plaintext = Nibble::ApiToken.issue(name: "Old", scopes: %w[read])

    delete "/cp/api-tokens/#{token.id}"

    assert Nibble::ApiToken.exists?(token.id)
    assert_nil Nibble::ApiToken.authenticate(plaintext)
  end

  test "minting a token needs a fresh password" do
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)

    post "/cp/api-tokens", params: { api_token: { name: "Stale", scopes: %w[read] } }

    assert_equal 0, Nibble::ApiToken.count
  end
end

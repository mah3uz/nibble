require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "the invitation renders, naming the site and the access being given" do
    body = PasswordsMailer.invite(users(:editor)).parts.map { |part| part.body.to_s }.join

    assert_match "Editor", body, "an invitation that cannot say what access it grants is not worth sending"
    assert_match users(:editor).email_address, body
  end

  test "the invitation is addressed with the site's own name rather than a hardcoded one" do
    Nibble::Records::GlobalSet.find_or_initialize_by(handle: "site") { |g| g.locale = "en" }.update!(data: { "name" => "Acme Docs" })

    assert_equal "You've been invited to Acme Docs", PasswordsMailer.invite(users(:editor)).subject
  end

  test "a site that has not named itself still gets a sensible subject" do
    Nibble::Records::GlobalSet.where(handle: "site").delete_all

    assert_equal "You've been invited to the site", PasswordsMailer.invite(users(:editor)).subject
  end

  test "the reset email renders with a working link" do
    body = PasswordsMailer.reset(users(:editor)).parts.map { |part| part.body.to_s }.join

    assert_match "/admin/passwords/", body
    assert_match "expires in 15 minutes", body
    assert_match users(:editor).email_address, body, "someone with more than one account needs to know which one this is"
  end

  test "links go to the site Nibble serves, whatever host the app gives its own mailers" do
    original = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: "app.internal" }

    body = PasswordsMailer.reset(users(:editor)).parts.map { |part| part.body.to_s }.join

    assert_match %r{https://example\.com/admin/passwords/}, body, "a reset link on the app's host would not reach this site"
    assert_no_match "app.internal", body
  ensure
    ActionMailer::Base.default_url_options = original
  end
end

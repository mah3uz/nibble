require "test_helper"

# 7.6: browser-enforced protections that don't depend on third-party origins, so they can't break
# tracking or widgets: no plugins, no <base> hijacking, no framing by other sites, and forms only
# post back to this site.
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  def csp = response.headers["Content-Security-Policy"].to_s.split(";").map(&:strip)

  test "public and Control Plane pages send the baseline content security policy" do
    [ "/nope", "/cp/session/new" ].each do |path|
      get path
      assert_includes csp, "object-src 'none'", path
      assert_includes csp, "base-uri 'self'", path
      assert_includes csp, "frame-ancestors 'self'", path
      assert_includes csp, "form-action 'self'", path
    end
  end

  test "the policy doesn't restrict script origins yet, so Google Ads, reCAPTCHA and Elfsight keep working" do
    get "/nope"
    assert_not csp.any? { |directive| directive.start_with?("script-src", "default-src") }, csp.join("; ")
  end
end

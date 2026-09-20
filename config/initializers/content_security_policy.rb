# Baseline Content Security Policy. It enforces the protections that don't depend on third-party
# origins: no plugins, no <base> hijacking, no framing by other sites (the admin preview iframe is
# same-origin), and forms post only to this site. Script, image and connect origins are not restricted
# yet: Google Ads conversions, reCAPTCHA and Elfsight load from many hosts, and an incomplete allowlist
# would silently break tracking. Tighten them from report-only data on staging.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.object_src :none
    policy.base_uri :self
    policy.frame_ancestors :self
    policy.form_action :self
  end
end

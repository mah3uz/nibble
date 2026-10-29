require "test_helper"

class FormKeysDocsTest < ActiveSupport::TestCase
  PAGE = Rails.root.join("vendor/nibble/docs/modelling/form-keys.md")

  # The code names the top-level keys, the limits and the connection keys; the nested keys of
  # notify, api, spam and success are read where they are used, so they are listed here.
  NESTED = {
    "success" => %w[message redirect],
    "notify" => %w[to cc bcc subject message reply_to fields] + Nibble::Conditions::KEYS,
    "api" => %w[url use path method format body mode errors error_fields retry],
    "api.errors" => %w[status path field message],
    "api.retry" => %w[attempts backoff_seconds],
    "spam" => %w[honeypot rate_limit captcha min_seconds max_links retention_days],
    "spam.rate_limit" => Nibble::Forms::DEFAULT_RATE_LIMIT.keys
  }.freeze

  def documented = PAGE.read.scan(/`([^`]+)`/).flatten

  def accepted_keys
    top = Nibble::Schema::Rules::KINDS.fetch("forms")[:keys].keys
    limits = Nibble::Forms::LIMIT_KEYS.map { |key| "limits.#{key}" }
    nested = NESTED.flat_map { |prefix, keys| keys.map { |key| "#{prefix}.#{key}" } }
    top + limits + nested
  end

  test "every key a form accepts is in the key table" do
    missing = accepted_keys - documented
    assert_empty missing, "form-keys.md doesn't list: #{missing.join(', ')}"
  end

  test "every key of an API connection is in the key table" do
    missing = Nibble::Schema::Rules::KINDS.fetch("apis")[:keys].keys - documented
    assert_empty missing, "form-keys.md doesn't list the API connection keys: #{missing.join(', ')}"
  end
end

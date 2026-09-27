module Nibble
  class OauthClient < Nibble::ApplicationRecord
    self.table_name = "nibble_oauth_clients"

    KINDS = %w[metadata registered builtin].freeze
    LOOPBACK_HOSTS = %w[127.0.0.1 localhost [::1]].freeze
    CLI_ID = "nibble-cli".freeze
    KNOWN = {
      CLI_ID => "Nibble CLI",
      "https://claude.ai/oauth/claude-code-client-metadata" => "Claude Code"
    }.freeze
    KNOWN_REDIRECTS = { "https://claude.ai/api/mcp/auth_callback" => "Claude" }.freeze

    has_many :grants, class_name: "Nibble::Grant", dependent: :destroy

    validates :client_id, presence: true, uniqueness: true
    validates :name, presence: true
    validates :kind, inclusion: { in: KINDS }
    validate :redirect_uris_are_safe

    def self.cli
      find_or_create_by!(client_id: CLI_ID) do |client|
        client.kind = "builtin"
        client.name = KNOWN[CLI_ID]
        client.redirect_uris = [ "http://127.0.0.1/callback" ]
      end
    end

    def self.safe_redirect?(uri)
      parsed = URI.parse(uri.to_s)
      return false unless parsed.host.present? && parsed.fragment.nil? && parsed.userinfo.nil?

      parsed.scheme == "https" || (parsed.scheme == "http" && LOOPBACK_HOSTS.include?(parsed.host))
    rescue URI::InvalidURIError
      false
    end

    def allows_redirect?(uri)
      requested = URI.parse(uri.to_s)
      redirect_uris.any? do |registered|
        next true if registered == uri.to_s

        allowed = URI.parse(registered)
        loopback?(allowed) && loopback?(requested) && requested.scheme == allowed.scheme &&
          requested.host == allowed.host && requested.path == allowed.path && requested.query == allowed.query
      end
    rescue URI::InvalidURIError
      false
    end

    def loopback_only? = redirect_uris.all? { |uri| loopback?(URI.parse(uri)) }

    def known_name
      return KNOWN[client_id] if KNOWN.key?(client_id)

      KNOWN_REDIRECTS[redirect_uris.first] if redirect_uris.any? && redirect_uris.all? { |uri| KNOWN_REDIRECTS.key?(uri) }
    end

    def id_host = kind == "metadata" ? URI.parse(client_id).host : nil

    def verified? = kind != "registered"

    private

    def loopback?(uri) = uri.scheme == "http" && LOOPBACK_HOSTS.include?(uri.host)

    def redirect_uris_are_safe
      errors.add(:redirect_uris, "must list at least one address") if redirect_uris.blank?
      unsafe = Array(redirect_uris).reject { |uri| self.class.safe_redirect?(uri) }
      errors.add(:redirect_uris, "must be https, or http on this computer: #{unsafe.to_sentence}") if unsafe.any?
    end
  end
end

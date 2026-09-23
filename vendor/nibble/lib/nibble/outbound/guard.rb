module Nibble
  module Outbound
    module Guard
      BLOCKED = %w[
        0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24
        192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
        ::/128 ::1/128 64:ff9b::/96 64:ff9b:1::/48 100::/64 2001::/32 2001:db8::/32 2002::/16 fc00::/7 fe80::/10 ff00::/8
      ].map { |range| IPAddr.new(range) }.freeze
      DNS_TIMEOUT = 3

      mattr_accessor :resolver, default: lambda { |host|
        dns = Resolv::DNS.new.tap { |resolver| resolver.timeouts = DNS_TIMEOUT }
        Resolv.new([ Resolv::Hosts.new, dns ]).getaddresses(host).map(&:to_s).uniq
      }

      module_function

      def blocked_ip?(address)
        ip = IPAddr.new(address.to_s)
        ip = ip.native if ip.ipv6?
        BLOCKED.any? { |range| range.family == ip.family && range.include?(ip) }
      rescue IPAddr::InvalidAddressError
        true
      end

      def check!(uri)
        raise Refused, "only http and https URLs can be called" unless %w[http https].include?(uri.scheme)

        host = uri.hostname.to_s.downcase
        raise Refused, "the URL has no host" if host.empty?
        raise Refused, "#{host} isn't in outbound.allowed_hosts" unless allowed_host?(host)

        addresses = literal(host) || resolver.call(host)
        raise Refused, "#{host} doesn't resolve" if addresses.empty?
        raise Refused, "#{host} points at a private or reserved address" if addresses.any? { |address| blocked_ip?(address) }

        addresses.first
      end

      def allowed_host?(host)
        allowed = Nibble.config.outbound_allowed_hosts
        allowed.empty? || allowed.any? { |pattern| pattern.start_with?("*.") ? host.end_with?(pattern.delete_prefix("*")) : host == pattern }
      end

      def literal(host)
        [ IPAddr.new(host.delete_prefix("[").delete_suffix("]")).to_s ]
      rescue IPAddr::InvalidAddressError
        nil
      end
    end
  end
end

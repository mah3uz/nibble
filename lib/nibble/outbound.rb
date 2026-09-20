module Nibble
  module Outbound
    class Refused < Error; end
    class Failed < Error; end

    Response = Data.define(:status, :headers, :body, :duration_ms) do
      def ok? = status.between?(200, 299)

      def json
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end
    end

    REDIRECTS = [ 301, 302, 303, 307, 308 ].freeze
    SENSITIVE_HEADER = /authorization|cookie|token|secret|signature|api[-_]?key/i
    LOGGED_BYTES = 4_096
    NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError, EOFError, Net::HTTPBadResponse ].freeze

    module_function

    def request(method, url, purpose:, body: nil, format: :json, headers: {}, timeout: 10, max_bytes: 1.megabyte, redirects: 3, owner: nil, secrets: [])
      method = method.to_s.upcase
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      uri = URI.parse(url.to_s)
      payload, content_type = encode(body, format)
      headers = { "User-Agent" => "Nibble", "Accept" => "application/json" }.merge(headers.to_h.transform_keys(&:to_s))
      headers["Content-Type"] ||= content_type if payload
      entry = { owner:, purpose:, method:, url: uri.to_s, headers:, payload:, secrets: }

      response = nil
      (redirects + 1).times do
        response = perform(method, uri, payload, headers, timeout, max_bytes, started)
        location = response.headers["location"]
        break unless REDIRECTS.include?(response.status) && location

        uri = uri + location
        entry[:url] = uri.to_s
        next unless [ 301, 302, 303 ].include?(response.status) && method != "GET"

        method = "GET"
        payload = nil
        headers = headers.except("Content-Type")
      end
      raise Refused, "stopped after #{redirects} redirects" if REDIRECTS.include?(response.status) && response.headers["location"]

      log(entry, response:)
      response
    rescue Refused, Failed => error
      log(entry, error:)
      raise
    rescue URI::InvalidURIError => error
      raise Refused, "the URL is invalid: #{error.message}"
    rescue *NETWORK_ERRORS => error
      failure = Failed.new("#{error.class.name.demodulize}: #{error.message}".truncate(250))
      log(entry, error: failure)
      raise failure
    end

    def perform(method, uri, payload, headers, timeout, max_bytes, started)
      address = Guard.check!(uri)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.ipaddr = address
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = http.write_timeout = http.ssl_timeout = timeout
      request = Net::HTTPGenericRequest.new(method, !payload.nil?, method != "HEAD", uri.request_uri, headers)
      request.body = payload

      http.start do |connection|
        connection.request(request) do |response|
          body = +""
          response.read_body do |chunk|
            body << chunk
            raise Failed, "the response is larger than #{max_bytes / 1024} KB" if body.bytesize > max_bytes
          end
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          return Response.new(status: response.code.to_i, headers: response.to_hash.transform_values(&:first), body:, duration_ms: elapsed)
        end
      end
    end

    def encode(body, format)
      return [ nil, nil ] if body.nil?
      return [ body, nil ] if body.is_a?(String)

      format.to_s == "form" ? [ URI.encode_www_form(body.to_h), "application/x-www-form-urlencoded" ] : [ body.to_json, "application/json" ]
    end

    def log(entry, response: nil, error: nil)
      return unless entry

      redact = ->(text) { entry[:secrets].compact_blank.reduce(text.to_s) { |value, secret| value.gsub(secret.to_s, "[secret]") } }
      Records::OutboundRequest.create!(
        owner_type: entry[:owner]&.record_type, owner_id: entry[:owner]&.id, purpose: entry[:purpose], method: entry[:method],
        url: redact.(entry[:url]).truncate(2_000),
        request_headers: entry[:headers].to_h { |name, value| [ name, name.match?(SENSITIVE_HEADER) ? "[redacted]" : redact.(value) ] },
        request_body: entry[:payload] && redact.(entry[:payload]).truncate(LOGGED_BYTES),
        status: response&.status, response_body: response && redact.(response.body).truncate(LOGGED_BYTES),
        error: error&.message, duration_ms: response&.duration_ms, created_at: Time.current
      )
    end
  end
end

module Nibble
  module Outbound
    Connection = Data.define(:item) do
      def self.find(handle, schema: Nibble.schema) = (item = schema.find(:apis, handle)) && new(item:)

      def handle = item.handle
      def base_url = item["base_url"]
      def timeout = item["timeout"] || 10
      def retry_policy = { "attempts" => 3, "backoff_seconds" => 30 }.merge(item["retry"].to_h)
      def error_mapping = item["errors"].to_h

      def url(path) = path.to_s.match?(%r{\Ahttps?://}) ? path.to_s : "#{base_url.chomp('/')}/#{path.to_s.delete_prefix('/')}"

      def request(method, path, purpose:, template: Template.new, headers: {}, body: nil, **options)
        rendered_headers = template.render(item["headers"].to_h).merge(headers)
        target = url(template.render(path))
        payload = template.render(body)
        Outbound.request(method, target, purpose:, headers: rendered_headers, body: payload, timeout:, secrets: template.secrets_used, **options)
      end
    end
  end
end

module Nibble
  # A rich-text link can name a global field ("global:site.apply_url") instead of an address, and render whatever that field holds.
  module GlobalLinks
    PATTERN = /\Aglobal:([a-z0-9][a-z0-9_-]*)\.([a-z][a-z0-9_]*)\z/

    module_function

    def parse(ref)
      match = PATTERN.match(ref.to_s) or return nil
      match.captures
    end

    def field(ref)
      handle, name = parse(ref)
      return nil if handle.nil? || handle == Integrations::HANDLE || !Nibble.schema.find(:globals, handle)

      field = Records::GlobalSet.new(handle:).blueprint_fields.get(name)
      field if field && address?(field)
    end

    def address?(field) = field.type == "link" || (field.type == "text" && field.get("input_type") == "url")

    # nil when the ref names no address field; "" when the field holds no safe address.
    def address(ref)
      field = field(ref) or return nil
      handle = parse(ref).first
      Dependencies.add("global:#{handle}")
      value = Records::GlobalSet.find_by(handle:, locale: Nibble.config.default_locale.code)&.values&.dig(field.handle)
      url = field.type == "link" ? field.with_value(value).fieldtype.augment(value)&.dig("url") : value
      SafeUrl.safe?(url) ? url.to_s.strip : ""
    end

    def refs(nodes)
      Array(nodes).flat_map do |node|
        next [] unless node.is_a?(Hash)

        Array(node["marks"]).filter_map { |mark| ref_of(mark) } + refs(node["content"])
      end
    end

    def unknown(nodes) = refs(nodes).uniq.reject { |ref| field(ref) }

    # Each link's stored href is kept at its global's current address, so an export or an older release still has one.
    def refresh(nodes)
      Array(nodes).map do |node|
        next node unless node.is_a?(Hash)

        node = node.merge("content" => refresh(node["content"])) if node["content"].is_a?(Array)
        next node unless node["marks"].is_a?(Array)

        node.merge("marks" => node["marks"].map { |mark| refresh_mark(mark) })
      end
    end

    def refresh_mark(mark)
      ref = ref_of(mark)
      address = ref && address(ref)
      address ? mark.merge("attrs" => mark["attrs"].merge("href" => address)) : mark
    end

    def ref_of(mark)
      mark["attrs"]["ref"].presence if mark.is_a?(Hash) && mark["type"] == "link" && mark["attrs"].is_a?(Hash)
    end

    def choices
      Nibble.schema.globals.filter_map do |item|
        next if item.handle == Integrations::HANDLE

        fields = Records::GlobalSet.new(handle: item.handle).blueprint_fields.select { |field| address?(field) }
        next if fields.empty?

        { "handle" => item.handle, "title" => item["title"] || item.handle.humanize,
          "fields" => fields.map { |field| { "handle" => field.handle, "display" => field.display, "address" => address("global:#{item.handle}.#{field.handle}") } } }
      end
    end
  end
end

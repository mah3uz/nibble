module Nibble
  module Views
    Sidecar = Data.define(:view, :path, :params, :queries, :page) do
      def page_include
        list = page["include"]
        list.is_a?(String) ? list.split(",").map(&:strip) : Array(list).map(&:to_s)
      end
    end

    class << self
      def sidecar(view, folder: "views", config: Nibble.config)
        path = config.theme_path&.join(folder, "#{view}.yml")
        return Sidecar.new(view:, path: nil, params: [], queries: {}, page: {}) unless path&.file?

        cache[[ path.to_s, path.mtime ]] ||= parse(view, path)
      end

      def set_params(config: Nibble.config) = sidecars(config:).select { |sidecar| sidecar.view.start_with?("sets/") }.flat_map(&:params).uniq

      def sidecars(folder: "views", config: Nibble.config)
        root = config.theme_path&.join(folder) or return []
        Dir.glob(root.join("**/*.yml")).sort.map do |file|
          sidecar(Pathname(file).relative_path_from(root).to_s.delete_suffix(".yml"), folder:, config:)
        end
      end

      # A layout whose file the theme lacks renders as default, so its queries are default's too.
      def layout_sidecar(layout, config: Nibble.config)
        layout = "default" unless config.theme_path&.join("layouts", "#{layout}.vue")&.file?
        sidecar(layout, folder: "layouts", config:)
      end

      def templates(config: Nibble.config)
        root = config.theme_path&.join("views") or return []
        Dir.glob("**/*.vue", base: root).map { |file| file.delete_suffix(".vue") }
          .reject { |view| view.start_with?("errors/", "sets/") }.sort
      end

      private

      def cache = @cache ||= {}

      def parse(view, path)
        raw = YAML.safe_load_file(path) || {}
        raise SchemaError.new(file: path, reason: "a sidecar must be a map of prop names to queries") unless raw.is_a?(Hash)

        params = Array(raw.delete("params")).map(&:to_s)
        # A page key with a source is a query that was named page before the key meant the page itself.
        page = raw["page"].is_a?(Hash) && !raw["page"].key?("from") ? raw.delete("page") : {}
        Sidecar.new(view:, path:, params:, queries: raw, page:)
      end
    end
  end
end

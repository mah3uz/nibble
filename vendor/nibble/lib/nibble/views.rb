module Nibble
  module Views
    Sidecar = Data.define(:view, :path, :params, :queries, :page, :extends) do
      def page_include
        list = page["include"]
        list.is_a?(String) ? list.split(",").map(&:strip) : Array(list).map(&:to_s)
      end
    end

    class << self
      def sidecar(view, folder: "views", config: Nibble.config)
        path = config.theme_path&.join(folder, "#{view}.yml")
        return Sidecar.new(view:, path: nil, params: [], queries: {}, page: {}, extends: nil) unless path&.file?

        cache[[ path.to_s, path.mtime ]] ||= parse(view, path, folder)
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
        extended(sidecar(layout, folder: "layouts", config:), config:)
      end

      def layout_sidecars(config: Nibble.config) = sidecars(folder: "layouts", config:).map { |item| extended(item, config:) }

      # The layouts a sidecar extends, nearest first; a cycle or a missing sidecar ends the chain.
      def ancestors(sidecar, config: Nibble.config)
        seen = [ sidecar.view ]
        chain = []
        while (name = sidecar.extends) && !seen.include?(name)
          sidecar = sidecar(name, folder: "layouts", config:)
          break unless sidecar.path

          seen << name
          chain << sidecar
        end
        chain
      end

      def templates(config: Nibble.config)
        root = config.theme_path&.join("views") or return []
        Dir.glob("**/*.vue", base: root).map { |file| file.delete_suffix(".vue") }
          .reject { |view| view.start_with?("errors/", "sets/") }.sort
      end

      private

      def cache = @cache ||= {}

      def extended(sidecar, config:)
        ancestors(sidecar, config:).reduce(sidecar) do |own, base|
          include = base.page_include | own.page_include
          own.with(params: base.params | own.params, queries: base.queries.merge(own.queries),
            page: include.empty? ? own.page : own.page.merge("include" => include))
        end
      end

      def parse(view, path, folder)
        raw = YAML.safe_load_file(path) || {}
        raise SchemaError.new(file: path, reason: "a sidecar must be a map of prop names to queries") unless raw.is_a?(Hash)

        params = Array(raw.delete("params")).map(&:to_s)
        # A page key with a source is a query that was named page before the key meant the page itself.
        page = raw["page"].is_a?(Hash) && !raw["page"].key?("from") ? raw.delete("page") : {}
        extends = raw.delete("extends")&.to_s if folder == "layouts"
        Sidecar.new(view:, path:, params:, queries: raw, page:, extends:)
      end
    end
  end
end

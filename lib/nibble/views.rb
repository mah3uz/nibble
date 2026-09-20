module Nibble
  module Views
    Sidecar = Data.define(:view, :path, :params, :queries)

    class << self
      def sidecar(view, config: Nibble.config)
        path = config.theme_path&.join("views", "#{view}.yml")
        return Sidecar.new(view:, path: nil, params: [], queries: {}) unless path&.file?

        cache[[ path.to_s, path.mtime ]] ||= parse(view, path)
      end

      def set_params(config: Nibble.config) = sidecars(config:).select { |sidecar| sidecar.view.start_with?("sets/") }.flat_map(&:params).uniq

      def sidecars(config: Nibble.config)
        root = config.theme_path&.join("views") or return []
        Dir.glob(root.join("**/*.yml")).sort.map do |file|
          sidecar(Pathname(file).relative_path_from(root).to_s.delete_suffix(".yml"), config:)
        end
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
        raise SchemaError.new(file: path, reason: "a view sidecar must be a map of prop names to queries") unless raw.is_a?(Hash)

        params = Array(raw.delete("params")).map(&:to_s)
        Sidecar.new(view:, path:, params:, queries: raw)
      end
    end
  end
end

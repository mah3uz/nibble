module Nibble
  class Theme
    REQUIRED_VIEWS = %w[pages/show posts/show posts/index taxonomies/show taxonomies/index search errors/404 errors/500].freeze
    MANIFEST_KEYS = %w[name handle version nibble description screenshot disable].freeze

    attr_reader :path, :manifest

    def self.load(path) = new(path)

    def initialize(path)
      @path = Pathname(path)
      file = @path.join("theme.yml")
      raise ConfigError.new("theme", "no theme.yml in #{@path}") unless file.file?

      @manifest = YAML.safe_load_file(file) || {}
      raise SchemaError.new(file:, reason: "theme.yml must be a map") unless @manifest.is_a?(Hash)
    end

    def handle = manifest["handle"] || path.basename.to_s
    def disable = Array(manifest["disable"]).map(&:to_s)
    def views_path = path.join("views")
    def layouts_path = path.join("layouts")
    def view?(name) = views_path.join("#{name}.vue").file?
    def layout?(name) = layouts_path.join("#{name}.vue").file?

    def manifest_problems
      problems = (manifest.keys - MANIFEST_KEYS).map { |key| "theme.yml: '#{key}' isn't a manifest key" }
      %w[name handle version nibble].each { |key| problems << "theme.yml: '#{key}' is required" if manifest[key].blank? }
      problems << "theme.yml: handle '#{handle}' must match the folder name '#{path.basename}'" if manifest["handle"] && handle != path.basename.to_s
      if manifest["nibble"].present? && !compatible?(manifest["nibble"].to_s)
        problems << "theme.yml: nibble '#{manifest['nibble']}' isn't compatible with theme API #{THEME_API_VERSION}"
      end
      problems
    end

    def compatible_with_core? = manifest["nibble"].present? && compatible?(manifest["nibble"].to_s)

    private

    def compatible?(range)
      major = range[/\A[\^~]?(\d+)/, 1] or return false
      major.to_i == THEME_API_VERSION
    end
  end
end

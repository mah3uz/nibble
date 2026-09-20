module Nibble
  class Install
    # Every install needs these; deploy files only when a site says how it deploys.
    CORE = { "nibble.yml.erb" => "config/nibble.yml", "env.erb" => ".env" }.freeze
    KAMAL = { "deploy.yml.erb" => "config/deploy.yml", "deploy.staging.yml.erb" => "config/deploy.staging.yml" }.freeze
    TEMPLATES = CORE.merge(KAMAL).freeze

    QUESTIONS = {
      name: "Application name (containers, image and volume are named after it)",
      url: "Public site URL",
      theme: "Theme handle"
    }.freeze

    KAMAL_QUESTIONS = {
      host: "Production domain",
      server: "Production server address",
      staging_host: "Staging domain",
      staging_server: "Staging server address",
      registry_user: "Container registry username",
      ssh_user: "SSH user on the servers"
    }.freeze

    Result = Data.define(:written, :skipped)

    VALIDATIONS = {
      name: [ /\A[a-z][a-z0-9-]*\z/, "lowercase letters, numbers and dashes — it names containers and volumes" ],
      theme: [ /\A[a-z][a-z0-9_-]*\z/, "a theme handle: lowercase letters, numbers, dashes and underscores" ],
      url: [ %r{\Ahttps?://[^\s]+\z}, "a full URL including http:// or https://" ],
      host: [ /\A[a-z0-9.-]+\.[a-z]{2,}\z/i, "a domain like example.com, with no scheme or path" ],
      staging_host: [ /\A[a-z0-9.-]+\.[a-z]{2,}\z/i, "a domain like staging.example.com, with no scheme or path" ]
    }.freeze

    def self.problem_with(key, value)
      rule = VALIDATIONS[key] or return nil
      pattern, expected = rule
      return nil if value.to_s.match?(pattern)

      "#{value.to_s.inspect} isn't #{expected}"
    end

    attr_reader :answers

    def self.defaults(root: Rails.root)
      name = root.basename.to_s.parameterize
      {
        name:, url: Nibble.site_url, theme: Nibble.build_theme,
        host: "example.com", server: "203.0.113.10",
        staging_host: "staging.example.com", staging_server: "203.0.113.11",
        registry_user: "your-registry-user", ssh_user: "root"
      }
    end

    def initialize(answers: {}, root: Rails.root, force: false, only: nil, kamal: false)
      @root = Pathname(root)
      @answers = self.class.defaults(root: @root).merge(answers.to_h.symbolize_keys).freeze
      @force = force
      @kamal = kamal
      @only = only && Array(only).map(&:to_s)
    end

    def run
      written = []
      skipped = []
      selected.each do |template, destination|
        path = @root.join(destination)
        next skipped << destination if path.exist? && !@force

        path.dirname.mkpath
        path.write(render(template))
        written << destination
      end
      Result.new(written:, skipped:)
    end

    def render(template)
      source = self.class.templates_path.join(template)
      raise Error, "no install template #{template}" unless source.file?

      ERB.new(source.read, trim_mode: "-").result(context)
    end

    def self.templates_path = Pathname(__dir__).join("install/templates")

    private

    def selected
      available = @kamal ? TEMPLATES : CORE
      return available if @only.blank?

      TEMPLATES.select { |_, destination| @only.any? { |name| destination.include?(name) } }
    end

    def context
      values = answers.merge(version: Nibble::VERSION)
      binding_object = Object.new
      values.each { |key, value| binding_object.define_singleton_method(key) { value } }
      binding_object.instance_eval { binding }
    end
  end
end

module Nibble
  class Install
    # Every file a site starts with, at the path it is written to; a .erb one is rendered from the answers.
    TEMPLATES_DIR = "vendor/nibble/templates".freeze
    TEMPLATES_PATH = Pathname(__dir__).join("../../templates").expand_path.freeze
    TEMPLATES = TEMPLATES_PATH.glob("**/*", File::FNM_DOTMATCH).select(&:file?).sort
      .to_h { |path| path.relative_path_from(TEMPLATES_PATH).to_s.then { |template| [ template, template.delete_suffix(".erb") ] } }.freeze
    # Deploy files only when a site says how it deploys; a site deploying some other way never gets them.
    KAMAL = TEMPLATES.select { |_, destination| %w[Dockerfile .dockerignore bin/docker-entrypoint].include?(destination) }.freeze
    CORE = TEMPLATES.except(*KAMAL.keys).freeze
    # Kamal scaffolds its own config, secrets and hooks; only what a Nibble site needs differently is ours.
    OVERLAY = Pathname(__dir__).join("install/deploy.overlay.yml.erb").freeze
    DEPLOY_FILE = "config/deploy.yml".freeze

    Regenerated = Data.define(:destination, :rendered, :current)

    QUESTIONS = {
      name: "Application name (containers, image and volume are named after it)",
      url: "Public site URL",
      theme: "Theme handle"
    }.freeze

    KAMAL_QUESTIONS = {
      host: "Production domain",
      server: "Production server address",
      registry_user: "Container registry username",
      ssh_user: "SSH user on the servers"
    }.freeze

    Result = Data.define(:written, :skipped)

    VALIDATIONS = {
      name: [ /\A[a-z][a-z0-9-]*\z/, "lowercase letters, numbers and dashes — it names containers and volumes" ],
      theme: [ /\A[a-z][a-z0-9_-]*\z/, "a theme handle: lowercase letters, numbers, dashes and underscores" ],
      url: [ %r{\Ahttps?://[^\s]+\z}, "a full URL including http:// or https://" ],
      host: [ /\A[a-z0-9.-]+\.[a-z]{2,}\z/i, "a domain like example.com, with no scheme or path" ]
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
        registry_user: "your-registry-user", ssh_user: "root"
      }
    end

    def initialize(answers: {}, root: Rails.root, force: false, only: nil, kamal: false, version: Nibble::VERSION)
      @root = Pathname(root)
      @answers = self.class.defaults(root: @root).merge(answers.to_h.symbolize_keys).freeze
      @force = force
      @kamal = kamal
      @only = only && Array(only).map(&:to_s)
      @version = version
    end

    def run
      written = []
      skipped = []
      selected.each do |template, destination|
        path = @root.join(destination)
        next skipped << destination if path.exist? && !@force

        path.dirname.mkpath
        path.write(render(template))
        path.chmod(self.class.templates_path.join(template).stat.mode)
        written << destination
      end
      if @kamal || @only == [ "deploy" ]
        @root.join(DEPLOY_FILE).file? && !@force ? skipped << DEPLOY_FILE : written.concat(deploy)
      end
      Result.new(written:, skipped:)
    end

    # The answers recorded at install are what lets an upgrade re-render a template a site owns the output of.
    def self.outdated(since:, answers:, version: Nibble::VERSION, root: Rails.root)
      TEMPLATES.filter_map do |template, destination|
        next if answers.blank?
        next unless changed?(template, since, root)

        current = root.join(destination)
        next unless current.file?

        rendered = new(answers:, root:, version:).render(template)
        Regenerated.new(destination:, rendered:, current: current.read) if rendered != current.read
      end
    end

    def self.changed?(template, since, root)
      system("git", "-C", root.to_s, "diff", "--quiet", since, "HEAD", "--", "#{TEMPLATES_DIR}/#{template}",
             out: File::NULL, err: File::NULL) == false
    end

    def render(template)
      source = template == OVERLAY ? OVERLAY : self.class.templates_path.join(template)
      raise Error, "no install template #{template}" unless source.file?
      return source.read unless source.extname == ".erb"

      ERB.new(source.read, trim_mode: "-").result(context)
    end

    def self.templates_path = TEMPLATES_PATH

    private

    # Kamal writes the file it owns, then the keys a Nibble site cannot do without are merged over it.
    def deploy
      scaffold = kamal_init
      path = @root.join(DEPLOY_FILE)
      return [] unless path.file?

      # Wholesale, not merged into: proxy names a host where we name hosts, and a leftover would be someone
      # else's domain sitting in a deploy config.
      scaffolded = YAML.safe_load(path.read, aliases: true) || {}
      path.write(YAML.dump(scaffolded.merge(YAML.safe_load(render(OVERLAY)))))
      scaffold + [ DEPLOY_FILE ]
    end

    def kamal_init
      return [] if @root.join(DEPLOY_FILE).file?

      unless system("kamal", "init", chdir: @root.to_s, out: File::NULL, err: File::NULL)
        raise Error, "kamal init failed, so there is nothing to deploy with: run it by hand in #{@root}"
      end

      [ ".kamal/secrets", ".kamal/hooks" ].select { |path| @root.join(path).exist? }
    end

    def selected
      available = @kamal ? TEMPLATES : CORE
      return available if @only.blank?
      # Deploying is one answer, not one file: a site adding it later needs everything that makes it deployable.
      return KAMAL if @only == [ "deploy" ]

      TEMPLATES.select { |_, destination| @only.any? { |name| destination.include?(name) } }
    end

    # Where the answered theme will be found: the site's own first, then one that ships with Nibble.
    def theme_dir
      theme = answers[:theme].to_s
      return "site/themes/#{theme}" if @root.join("site/themes", theme).directory?

      Nibble.core_root.join("themes", theme).directory? ? "vendor/nibble/themes/#{theme}" : "site/themes/#{theme}"
    end

    def context
      values = answers.merge(version: @version, theme_dir:)
      binding_object = Object.new
      values.each { |key, value| binding_object.define_singleton_method(key) { value } }
      binding_object.instance_eval { binding }
    end
  end
end

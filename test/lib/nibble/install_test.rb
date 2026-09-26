require "test_helper"

class Nibble::InstallTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir("nibble-install"))
    stub_kamal
  end

  # Deploying scaffolds with Kamal's own init, so a test needs one that behaves like it and touches nothing.
  def stub_kamal
    @bin_dir = Pathname(Dir.mktmpdir("nibble-bin"))
    ENV["PATH"] = "#{@bin_dir}:#{ENV['PATH']}"
    bin = @bin_dir.join("kamal")
    bin.dirname.mkpath
    bin.write(<<~SH)
      #!/bin/sh
      mkdir -p config .kamal/hooks
      printf 'service: my-app\nimage: my-user/my-app\nservers:\n  web:\n    - 192.168.0.1\n' > config/deploy.yml
      printf 'KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD\n' > .kamal/secrets
      touch .kamal/hooks/pre-deploy.sample
    SH
    bin.chmod(0o755)
  end
  teardown do
    ENV["PATH"] = ENV["PATH"].sub("#{@bin_dir}:", "") if @bin_dir
    FileUtils.rm_rf([ @root, @bin_dir, @previous ].compact)
  end

  def install(force: false, only: nil, kamal: false, **answers) = Nibble::Install.new(answers:, root: @root, force:, only:, kamal:)

  test "an install writes the whole application around Nibble, leaving deployment alone" do
    result = install(name: "acme", url: "https://acme.test").run

    assert_includes result.written, "Gemfile", "without it nothing loads vendor/nibble"
    assert_includes result.written, "config/application.rb"
    assert_includes result.written, "config/nibble.yml"
    assert_includes result.written, "site/README.md"
    assert_includes result.written, "test/test_helper.rb", "a site's own tests need somewhere to start from"
    assert_includes result.written, ".gitignore", "without it a site commits its logs, keys and builds"
    assert_not_includes result.written, "Dockerfile"
    assert_not_includes result.written, "bin/docker-entrypoint"
    assert_not @root.join("config/deploy.yml").exist?, "a site that hasn't said how it deploys gets no deploy files"
  end

  test "only a file the site changed is reported as kept, so the report isn't dozens of lines of our own files" do
    install(name: "acme").run
    @root.join("config/routes.rb").write("Rails.application.routes.draw { get 'x', to: 'site#show' }\n")

    assert_equal [ "config/routes.rb" ], install(name: "acme").run.skipped
  end

  test "an install never writes into vendor/nibble, which an upgrade replaces whole" do
    written = install(name: "acme").run.written

    assert_empty written.grep(%r{\Avendor/})
  end

  test "scripts stay executable, or the first command a new site runs fails" do
    install(name: "acme").run

    assert @root.join("bin/rails").executable?
    assert @root.join("bin/setup").executable?
    assert_not @root.join("config/routes.rb").executable?
  end

  test "the editor and the build look for the chosen theme where it lives" do
    install(name: "acme", theme: "crumbs").run
    assert_includes @root.join("tsconfig.app.json").read, "./vendor/nibble/themes/crumbs/*"

    other = Pathname(Dir.mktmpdir("nibble-install"))
    Nibble::Install.new(answers: { name: "acme", theme: "almanac" }, root: other).run
    assert_includes other.join("tsconfig.app.json").read, "./site/themes/almanac/*",
                    "a theme Nibble doesn't ship can only be the site's own"
  ensure
    FileUtils.rm_rf(other) if other
  end

  test "saying Kamal is how you deploy adds the deploy files" do
    written = install(name: "acme", kamal: true).run.written

    assert_includes written, "Dockerfile"
    assert_includes written, ".dockerignore"
    assert_includes written, "bin/docker-entrypoint"
    assert @root.join("bin/docker-entrypoint").executable?, "the image can't start without it"
    assert_equal [ ".kamal/secrets", ".kamal/hooks", "config/deploy.yml" ], written.last(3)
  end

  test "deploy files can be added later without redoing the install" do
    install(name: "acme").run
    result = install(name: "acme", only: "deploy").run

    assert_equal [ ".dockerignore", ".kamal/hooks", ".kamal/secrets", "Dockerfile", "bin/docker-entrypoint", "config/deploy.yml" ],
                 result.written.sort
  end

  test "the generated settings load, so an install is never one restart from a config error" do
    install(name: "acme", url: "https://acme.test", theme: "crumbs").run
    values = YAML.safe_load_file(@root.join("config/nibble.yml"), aliases: true).fetch("production")
    config = Nibble::Config.new(values)

    assert_equal "https://acme.test", config.url
    assert_equal "crumbs", config.theme
    assert_equal "en", config.default_locale.code
    assert_includes config.reserved_paths, "/cp"
  end

  test "the generated settings pin behaviour to this release, so a later upgrade changes nothing on its own" do
    install.run
    values = YAML.safe_load_file(@root.join("config/nibble.yml"), aliases: true).fetch("production")

    assert_equal Nibble::VERSION, Nibble::Config.new(values).load_defaults
  end

  test "a second install keeps what the site has rather than overwriting its answers" do
    install(name: "acme", kamal: true).run
    @root.join("config/deploy.yml").write("service: edited-by-hand\n")

    result = install(name: "other", kamal: true).run

    assert_includes result.skipped, "config/deploy.yml"
    assert_equal "service: edited-by-hand\n", @root.join("config/deploy.yml").read
    assert_equal "service: other\n", install(name: "other", force: true, only: "deploy").run.then { @root.join("config/deploy.yml").read[/^service: .*\n/] }
  end

  test "answers reach every file that needs them" do
    install(kamal: true, name: "acme", host: "acme.test", server: "198.51.100.7", registry_user: "acme-co", ssh_user: "deploy").run
    deploy = @root.join("config/deploy.yml").read

    assert_match(/^service: acme$/, deploy)
    assert_match(/^image: acme-co\/acme$/, deploy)
    assert_match "198.51.100.7", deploy
    assert_match(/user: deploy/, deploy)
    assert_equal [ "./acme-storage:/rails/storage" ], YAML.safe_load(deploy)["volumes"],
      "storage is a folder in the deploy user's home on the server, not a volume hidden under Docker's own path"
  end

  test "an answer that would produce a broken file is rejected with what was expected" do
    assert_match "http", Nibble::Install.problem_with(:url, "acme.test")
    assert_match "containers", Nibble::Install.problem_with(:name, "Bad Name")
    assert_match "no scheme", Nibble::Install.problem_with(:host, "https://acme.test")
  end

  test "a good answer passes, and a key with nothing to check never blocks the install" do
    assert_nil Nibble::Install.problem_with(:url, "https://acme.test")
    assert_nil Nibble::Install.problem_with(:name, "acme")
    assert_nil Nibble::Install.problem_with(:ssh_user, "anything at all")
  end

  test "a template that has moved on since the install is offered against the site's own file" do
    previous = previous_templates
    install(url: "https://notes.example", name: "notes").run
    @root.join("config/nibble.yml").write("production:\n  theme: stale\n")

    offered = Nibble::Install.outdated(previous:, answers: { url: "https://notes.example", name: "notes" }, root: @root)

    assert_equal [ "config/nibble.yml" ], offered.map(&:destination)
    assert_equal "production:\n  theme: stale\n", offered.sole.current
    assert_includes offered.sole.rendered, "notes", "the re-render has to use this site's own answers, not ours"
  end

  test "re-rendering keeps the version a site is on, so an upgrade never switches new behaviour on" do
    previous = previous_templates
    install(url: "https://notes.example").run
    @root.join("config/nibble.yml").write("production:\n  theme: stale\n")

    offered = Nibble::Install.outdated(previous:, answers: { url: "https://notes.example" }, version: "0.0.9", root: @root)

    assert_includes offered.sole.rendered, %(load_defaults: "0.0.9")
    assert_not_includes offered.sole.rendered, Nibble::VERSION,
                        "taking the running release's number here would turn on behaviour the site never opted into"
  end

  test "a template nobody touched is left out, so an upgrade only asks about what changed" do
    previous = previous_templates(moved_on: false)
    install(url: "https://notes.example").run
    @root.join("config/nibble.yml").write("production:\n  theme: stale\n")

    assert_empty Nibble::Install.outdated(previous:, answers: { url: "https://notes.example" }, root: @root)
  end

  test "a template the previous release didn't have counts as moved on" do
    previous = previous_templates(moved_on: false)
    previous.join("config/nibble.yml.erb").delete
    install(url: "https://notes.example").run
    @root.join("config/nibble.yml").write("production:\n  theme: stale\n")

    assert_equal [ "config/nibble.yml" ], Nibble::Install.outdated(previous:, answers: { url: "https://notes.example" }, root: @root).map(&:destination)
  end

  test "without recorded answers nothing is offered, rather than a file rendered from our defaults" do
    previous = previous_templates
    install(url: "https://notes.example").run

    assert_empty Nibble::Install.outdated(previous:, answers: {}, root: @root),
                 "re-rendering with defaults would overwrite a site's hosts and URLs with ours"
  end

  private

  # The templates of the release a site is upgrading from: ours, with config/nibble.yml.erb as it was before.
  def previous_templates(moved_on: true)
    previous = @previous = Pathname(Dir.mktmpdir("nibble-previous"))
    FileUtils.cp_r(Nibble::Install.templates_path.children, previous)
    previous.join("config/nibble.yml.erb").write("# the template as it was\n") if moved_on
    previous
  end
end

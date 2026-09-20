require "test_helper"

class Nibble::InstallTest < ActiveSupport::TestCase
  setup { @root = Pathname(Dir.mktmpdir("nibble-install")) }
  teardown { FileUtils.rm_rf(@root) }

  def install(force: false, only: nil, kamal: false, **answers) = Nibble::Install.new(answers:, root: @root, force:, only:, kamal:)

  test "an install writes only what every site needs, leaving deployment alone" do
    result = install(name: "acme", url: "https://acme.test").run

    assert_equal [ "config/nibble.yml", ".env" ], result.written
    assert_not @root.join("config/deploy.yml").exist?, "a site that hasn't said how it deploys gets no deploy files"
  end

  test "saying Kamal is how you deploy adds the deploy files" do
    result = install(name: "acme", kamal: true).run

    assert_equal [ "config/nibble.yml", ".env", "config/deploy.yml", "config/deploy.staging.yml" ], result.written
  end

  test "deploy files can be added later without redoing the install" do
    install(name: "acme").run
    result = install(name: "acme", only: "deploy").run

    assert_equal [ "config/deploy.yml", "config/deploy.staging.yml" ], result.written
  end

  test "the generated settings load, so an install is never one restart from a config error" do
    install(name: "acme", url: "https://acme.test", theme: "crumbs").run
    values = YAML.safe_load_file(@root.join("config/nibble.yml"), aliases: true).fetch("production")
    config = Nibble::Config.new(values)

    assert_equal "https://acme.test", config.url
    assert_equal "crumbs", config.theme
    assert_equal "en", config.default_locale.code
    assert_includes config.reserved_paths, "/admin"
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
    assert_equal "service: other\n", install(name: "other", force: true, only: "deploy.yml").run.then { @root.join("config/deploy.yml").read[/^service: .*\n/] }
  end

  test "answers reach every file that needs them" do
    install(kamal: true, name: "acme", host: "acme.test", server: "198.51.100.7", registry_user: "acme-co", ssh_user: "deploy").run
    deploy = @root.join("config/deploy.yml").read

    assert_match(/^service: acme$/, deploy)
    assert_match(/^image: acme-co\/acme$/, deploy)
    assert_match "198.51.100.7", deploy
    assert_match(/user: deploy/, deploy)
    assert_match(/- acme-co-storage:|- acme-storage:/, deploy)
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
end

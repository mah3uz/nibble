require_relative "clean_failures"
require_relative "admin_interview"
require_relative "release_upgrade"
require_relative "nibble_help"

class NibbleCommand < Rails::Command::Base
  include AdminInterview
  include ReleaseUpgrade
  extend CleanFailures

  BUDGETS = { cached: 50, uncached: 300, queries: 15, listing: 150, listing_queries: 12 }.freeze

  desc "build", "Check everything derived from files, and generate what a build needs"
  def build
    boot_application!
    write_types
    check = Nibble::Check.run(static: true)
    check.warnings.each { |warning| warn "! #{warning}" }
    check.problems.each { |problem| warn "✗ #{problem}" }
    abort "the schema has #{check.problems.size} problem(s)" unless check.ok?

    index = Nibble::Files.reload!
    index.problems.each { |problem| warn "✗ #{problem}" }
    abort "content has #{index.problems.size} problem(s)" if index.problems.any?

    puts "content: #{index.pages.size} page(s) in #{Nibble::Files.collections.size} collection(s)"
  end

  desc "check", "Check the schema, theme, roles, pending content migrations and data the schema no longer covers"
  option :allow_data_loss, type: :boolean, desc: "Report data the schema no longer covers as warnings instead of failing"
  option :support, type: :boolean, desc: "Also print a summary of this install to paste into an issue"
  def check
    boot_application!
    check = Nibble::Check.run(allow_data_loss: options[:allow_data_loss])
    check.warnings.each { |warning| warn "! #{warning}" }
    support if options[:support]
    if check.ok?
      puts "nibble:check passed (#{Nibble.schema.items.size} schema files)"
    else
      check.problems.each { |problem| warn "✗ #{problem}" }
      abort "nibble:check found #{check.problems.size} problem(s)"
    end
  end

  desc "prepare", "Bring the database up to this release: compatibility, database and content migrations, check, schema snapshot"
  option :allow_data_loss, type: :boolean, desc: "Carry on even when the schema no longer covers some stored data"
  def prepare
    boot_application!
    result = Nibble::Prepare.run(allow_data_loss: options[:allow_data_loss], log: ->(line) { puts line })
    result.warnings.each { |warning| warn "! #{warning}" }
    result.migrations.each do |migration|
      puts "content migration #{migration.name}"
      migration.counts.each { |label, count| puts "  #{label}: #{count}" }
    end
    puts result.snapshot ? "schema snapshot recorded" : "schema unchanged since the last snapshot"
    puts "prepared for #{Nibble::VERSION}"
  rescue Nibble::Prepare::Stopped => e
    abort "prepare stopped: #{e.message}"
  end

  # The release, what it runs on and every command, not Thor's list of this namespace alone.
  def self.help(shell, subcommand = false) = NibbleHelp.print(shell)

  desc "version", "Print the Nibble version this site runs"
  # Read from Nibble's own files rather than a booted app, so it still answers when the site won't boot.
  def version
    puts NibbleHelp.running
    recorded = NibbleHelp.recorded&.fetch("version", nil)
    warn "config/nibble.yml records #{recorded}: an upgrade to #{NibbleHelp.running} didn't finish" if recorded && recorded != NibbleHelp.running
  end

  desc "upgrade [VERSION]", "Take a Nibble release (the latest by default): check it, snapshot, swap it in, migrate"
  option :force, type: :boolean, desc: "Replace Nibble's files even where they were changed here"
  option :allow_data_loss, type: :boolean, desc: "Carry on even when the schema no longer covers some stored data"
  def upgrade(version = nil)
    take_release(version, [ ("--force" if options[:force]), ("--allow-data-loss" if options[:allow_data_loss]) ].compact)
  end

  desc "install", "Set up this site: settings, deploy files, database, first admin"
  option :defaults, type: :boolean, desc: "Take every default instead of asking"
  option :force, type: :boolean, desc: "Overwrite files a previous install generated"
  option :only, type: :string, desc: "Generate one file only, e.g. --only=deploy"
  option :kamal, type: :boolean, desc: "Write the Kamal deploy files too (asked for when not given)"
  def install
    boot_application!
    banner
    answers, kamal = options[:defaults] ? [ {}, !!options[:kamal] ] : interview
    installer = Nibble::Install.new(answers:, force: options[:force], only: options[:only], kamal:)
    result = installer.run

    section "Files"
    result.written.each { |path| say_status :create, path, :green }
    result.skipped.each { |path| say_status :keep, "#{path} — yours already, left alone", :yellow }
    master_key
    # What was rendered, defaults included, so an upgrade can render the same files again; deploy answers only if asked.
    # Taking defaults again never replaces what an earlier install recorded.
    asked = Nibble::Install::QUESTIONS.keys + (kamal ? Nibble::Install::KAMAL_QUESTIONS.keys : [])
    rendered = installer.answers.slice(*asked) unless options[:defaults] && Nibble::Release.installed
    Nibble::Release.record_install(version: Nibble::VERSION, answers: rendered)
    say_status :record, "#{Nibble::Metadata::FILE} — this install is #{Nibble::VERSION}", :green
    if options[:only]
      admin_reminder
    elsif options[:defaults]
      prepare_database
      admin_reminder
    else
      set_up_database
    end
    next_steps(kamal)
  end

  desc "eject PATH", "Copy one of Nibble's files into site/ so this site can change it, and record that it did"
  option :force, type: :boolean, desc: "Take a fresh copy over an existing override"
  def eject(path)
    boot_application!
    ejection = Nibble::Eject.run(path, force: options[:force])
    puts "ejected #{ejection.source}"
    puts "     to #{ejection.target}"
    warn "! #{ejection.target} is yours now: it stops following Nibble's copy, including fixes. " \
         "bin/rails nibble:check reports when the original changes."
  rescue Nibble::Eject::Refused => e
    abort "eject refused: #{e.message}"
  end

  desc "bench", "Measure public render times against the performance budgets (use a disposable database)"
  option :posts, type: :numeric, default: 200, desc: "Posts to seed before measuring"
  option :requests, type: :numeric, default: 50, desc: "Requests per path"
  def bench
    boot_application!
    abort "run this against a disposable database (RAILS_ENV=test)" if Rails.env.production?

    posts = options[:posts]
    requests = options[:requests]
    Nibble::PageCache.store = ActiveSupport::Cache::MemoryStore.new
    seed(posts)

    app = Rack::MockRequest.new(Rails.application)
    paths = [ "/blog", Nibble::Records::Entry.live.where(collection: "posts").first.uri, "/topics" ].compact
    results = %i[uncached cached].to_h { |mode| [ mode, measure(app, paths, requests, mode) ] }

    breaches = []
    puts "posts: #{Nibble::Records::Entry.live.where(collection: 'posts').count} · requests per path: #{requests}"
    results.each do |mode, measured|
      puts format("%-9s p95 %6.1f ms (budget %d ms) · max queries %d", mode, measured[:p95], BUDGETS[mode], measured[:queries])
      breaches << "#{mode} p95 #{measured[:p95].round(1)} ms over #{BUDGETS[mode]} ms" if measured[:p95] > BUDGETS[mode]
      breaches << "#{mode} #{measured[:queries]} queries over #{BUDGETS[:queries]}" if measured[:queries] > BUDGETS[:queries]
    end
    listing = measure_listing(requests)
    puts format("%-9s p95 %6.1f ms (budget %d ms) · queries %d", "listing", listing[:p95], BUDGETS[:listing], listing[:queries])
    breaches << "listing p95 #{listing[:p95].round(1)} ms over #{BUDGETS[:listing]} ms" if listing[:p95] > BUDGETS[:listing]
    breaches << "listing #{listing[:queries]} queries over #{BUDGETS[:listing_queries]}" if listing[:queries] > BUDGETS[:listing_queries]
    abort "performance budget breached: #{breaches.join('; ')}" if breaches.any?
    puts "within budget"
    puts "the benchmark seeded this database: run bin/rails db:test:prepare before the test suite"
  end

  private

  # Before the check, which would otherwise refuse types this command exists to bring up to date. A schema too broken
  # to generate from is left for the check to report.
  def write_types
    output = Nibble::TypeGenerator.write! or return
    puts "types: #{output.relative_path_from(Rails.root)}"
  rescue Nibble::Error
    nil
  end

  def banner
    say ""
    say "  Nibble #{Nibble::VERSION}", :green
    say "  Setting up this site. Press enter to take the value in brackets.", :white
  end

  def section(title)
    say ""
    say "  #{title}", :cyan
  end

  def interview
    section "Your site"
    answers = ask_answers(Nibble::Install::QUESTIONS)

    section "Deployment"
    say "  Kamal deploys this app to your own server. Say no for now if you are only running it locally —", :white
    say "  bin/rails nibble:install --only=deploy adds these files whenever you are ready.", :white
    kamal = options[:kamal].nil? ? yes?("  Deploy with Kamal?", :cyan) : options[:kamal]
    answers.merge!(ask_answers(Nibble::Install::KAMAL_QUESTIONS)) if kamal
    [ answers, !!kamal ]
  end

  def ask_answers(questions)
    defaults = Nibble::Install.defaults
    questions.to_h do |key, prompt|
      [ key, ask_value(prompt, defaults[key], key) ]
    end
  end

  def ask_value(prompt, default, key)
    loop do
      answer = ask("  #{prompt}", :cyan, default: default.to_s)
      answer = answer.to_s.strip
      return default.to_s if answer.empty?

      problem = Nibble::Install.problem_with(key, answer) or return answer

      say "  #{problem}", :red
    end
  end

  def set_up_database
    section "Your account"
    prepare_database
    create_admin
    import_starter_content
  end

  def prepare_database
    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:prepare")
    Rake::Task["db:prepare"].invoke
    say_status :create, "the database", :green
  end

  def create_admin
    return say_status(:keep, "an administrator already exists — signing in is how you get back", :yellow) if User.administrators.exists?

    say "  Nibble needs one administrator to sign in with. There is no way in without it.", :white
    Role.seed_defaults!
    user = build_admin
    say_status :create, "administrator #{user.email_address}", :green
  end

  def admin_reminder
    return if User.administrators.exists?

    say_status :todo, "no administrator yet — run bin/rails nibble:admin:create", :yellow
  rescue ActiveRecord::StatementInvalid
    nil
  end

  def import_starter_content
    package = Nibble::STARTER_CONTENT
    return unless package.directory?

    say "  Nibble can start you off with example pages and posts. Skip this for an empty site.", :white
    wanted = yes?("  Import them?", :cyan)
    say ""
    return say_status(:keep, "no content imported — the site starts empty", :yellow) unless wanted

    report = Nibble::Packages::Importer.new(package.to_s, mode: "create").call
    return report.errors.each { |error| say "  #{error}", :red } unless report.ok?

    Nibble::Events.dispatch_pending
    say_status :create, "#{report.created.size} items of starter content", :green
  end

  def next_steps(kamal)
    section "Next"
    say "  bin/rails nibble:check        confirm the schema and settings are sound", :white
    say "  bin/dev                       start the site", :white
    say "  bin/kamal setup               first deploy, once the servers in config/deploy.yml are yours", :white if kamal
    say ""
  end

  def master_key
    path = Rails.root.join("config/master.key")
    return say_status(:keep, "config/master.key — yours already, left alone", :yellow) if path.exist?

    path.write(ActiveSupport::EncryptedFile.generate_key)
    path.chmod(0o600)
    # Production refuses to boot without a secret_key_base, and Rails reads it from here.
    Rails.application.encrypted("config/credentials.yml.enc")
      .write("# Secrets for this site. Edit with: bin/rails credentials:edit\nsecret_key_base: #{SecureRandom.hex(64)}\n")
    say_status :create, "config/credentials.yml.enc", :green
    say_status :create, "config/master.key — never commit it, and keep a copy somewhere safe", :green
  end

  def support
    theme = Nibble.config.active_theme
    ejected = Nibble::Eject.manifest
    stale = Nibble::Eject.stale.map(&:target)
    puts "--- nibble support ---"
    installed = Nibble::Release.installed
    puts "nibble:   #{Nibble::VERSION} · installed record: #{installed ? "#{installed.version} since #{installed.at}" : "none"}"
    puts "ruby:     #{RUBY_VERSION} · rails: #{Rails.version} · env: #{Rails.env}"
    puts "database: #{ActiveRecord::Base.connection_db_config.adapter}"
    puts "theme:    #{theme ? "#{theme.handle} #{theme.manifest['version']} (nibble #{theme.manifest['nibble']})" : "none"}"
    puts "schema:   #{Nibble.schema.items.size} files · site layer: #{Nibble.site_schema_path.glob("**/*.yml").size} files"
    puts "ejected:  #{ejected.empty? ? "none" : ejected.keys.join(", ")}"
    puts "stale:    #{stale.empty? ? "none" : stale.join(", ")}"
    puts "--- end ---"
  end

  def seed(posts)
    if Nibble::STARTER_CONTENT.directory?
      report = Nibble::Packages::Importer.new(Nibble::STARTER_CONTENT).call
      abort "the starter package didn't import: #{report.errors.join('; ')}" unless report.ok?
    end
    missing = posts - Nibble::Records::Entry.kept.where(collection: "posts").count
    return if missing <= 0

    print "seeding #{missing} posts"
    images = bench_images
    Nibble::DemoContent.new(images:).seed(missing)
    Nibble::Events.dispatch_pending
    puts
  end

  def bench_images
    existing = Nibble::Records::Asset.kept.where(kind: "image").to_a
    return existing if existing.size >= 3

    fixture = Rails.root.join("test/fixtures/files/photo.jpg")
    existing + (existing.size...3).map do |index|
      blob = ActiveStorage::Blob.create_and_upload!(io: fixture.open, filename: "bench-#{index}.jpg")
      Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, {}).record
    end
  end

  # The posts listing with every column on, as someone browsing the Control Plane would see it.
  def measure_listing(requests)
    user = User.administrators.first || User.create!(email_address: "bench@example.test", name: "Bench", password: SecureRandom.hex(16),
      roles: [ Role.tap(&:seed_defaults!).find_by!(handle: "admin") ])
    collection = Nibble.schema.collection("posts")
    listing = -> { Nibble::Cp::Listing.new(collection, user:, params: ActionController::Parameters.new(per_page: "100")) }
    UserPreferences.set!(user, "listings.collections_posts.columns", listing.call.props["columns"].map { |column| column["handle"] })
    listing.call.props
    timings = requests.times.map do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      _, queries = Nibble::QueryCounter.count { listing.call.props }
      [ (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, queries ]
    end
    { p95: percentile(timings.map(&:first), 95), queries: timings.map(&:last).max }
  end

  def measure(app, paths, requests, mode)
    timings = paths.flat_map do |path|
      Nibble::PageCache.store.clear if mode == :uncached
      app.get(path) if mode == :cached
      requests.times.map do
        Nibble::PageCache.store.clear if mode == :uncached
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = app.get(path)
        raise "#{path} returned #{response.status}" unless response.status == 200

        [ (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, response.headers["X-Nibble-Queries"].to_i ]
      end
    end
    { p95: percentile(timings.map(&:first), 95), queries: timings.map(&:last).max }
  end

  def percentile(values, rank)
    sorted = values.sort
    sorted[[ (sorted.size * rank / 100.0).ceil - 1, 0 ].max]
  end
end

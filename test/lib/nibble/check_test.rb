require "test_helper"

class Nibble::CheckTest < ActiveSupport::TestCase
  setup { @themes = Pathname(Dir.mktmpdir("nibble-themes")) }
  teardown { FileUtils.rm_rf(@themes) }

  def theme_file(relative, content)
    path = @themes.join("check", "schema", relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(content.is_a?(String) ? content : content.deep_stringify_keys.to_yaml)
  end

  def check(theme: "check", static: false)
    config = Nibble::Config.new({ "theme" => theme, "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes)
    Nibble::Check.run(config:, static:)
  end

  # An image is built without the key that reads secrets, so a build that asked for them could never pass.
  test "a static check says nothing about settings it cannot see from a build" do
    sources = check(static: true).findings.map(&:source)

    assert_not_includes sources, "RAILS_MASTER_KEY"
    assert_not_includes sources, "mail"
    assert_not_includes sources, "backups"
  end

  test "a form that needs a CAPTCHA warns, not fails, while Integrations has no keys" do
    theme_file("forms/signup.yml", title: "Signup", fields: [ { handle: "email", field: { type: "text", input_type: "email" } } ],
      spam: { captcha: true }, success: { message: "Thanks!" })

    result = check
    assert(result.warnings.any? { |warning| warning.source.end_with?("forms/signup.yml") && warning.message.include?("no CAPTCHA keys") })
    assert_empty result.problems.select { |problem| problem.source.include?("forms/signup") }

    original = Nibble::Integrations.method(:captcha)
    Nibble::Integrations.define_singleton_method(:captcha) { { "provider" => "turnstile" } }
    assert_not check.warnings.any? { |warning| warning.message.include?("no CAPTCHA keys") }
  ensure
    Nibble::Integrations.define_singleton_method(:captcha, original) if original
  end

  test "allow_private_networks is an error where it is ignored, and fine in development and test" do
    config = Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ], "outbound" => { "allow_private_networks" => true } }, themes_path: @themes)

    assert Nibble::Check.run(config:).problems.none? { |problem| problem.source == "outbound.allow_private_networks" }
    Rails.env = "production"
    assert Nibble::Check.run(config:, static: true).problems.any? { |problem| problem.source == "outbound.allow_private_networks" }
  ensure
    Rails.env = "test"
  end

  test "a database that isn't set up is one problem naming the fix, not a crash on its missing tables" do
    check = Nibble::Check.new(config: Nibble.config)
    check.define_singleton_method(:database_behind?) { true }

    check.run

    assert_includes check.problems.map(&:to_s), "database: not set up, or has migrations to run: run bin/rails db:prepare"
  end

  test "the shipped core baseline schema passes, so a fresh install boots on a valid schema" do
    result = check(theme: nil)
    assert result.ok?, result.problems.map(&:to_s).join("\n")
  end

  test "a form may only use public-safe fields, and its spam, API and success settings must be complete" do
    theme_file("forms/contact.yml", title: "Contact", fields: [
      { handle: "name", field: { type: "text", validate: [ "required" ] } },
      { handle: "related", field: { type: "entries" } },
      { handle: "website", field: { type: "text" } }
    ], spam: { honeypot: "website", captcha: "turnstile", rate_limit: { requests: 0 } },
      api: [ { use: "crm" }, { url: "ftp://example.test", mode: "later" } ], notify: [ { subject: "New" }, { to: "team@example.test", fields: [ "phone" ], reply_to: "phone" } ],
      handler: "crm.missing", success: { redirect: "thanks" })

    problems = check.problems.map(&:to_s).join("\n")
    [
      "field 'related' uses 'entries', which can't be used on a public form",
      "field handle 'website' clashes with the honeypot",
      "spam.rate_limit needs positive requests and per_minutes",
      "spam.captcha must be true or false",
      "api.0 uses the API connection 'crm', which isn't in the schema",
      "api.1.url must be an absolute http(s) URL",
      "api.1.mode must be sync or async",
      "notify.0 must be a mapping with a `to` address",
      "notify.1.fields must be a list of the form's field handles",
      "notify.1.reply_to must be one of the form's field handles",
      "handler 'crm.missing' isn't registered",
      "success needs a message or a redirect"
    ].each { |message| assert_includes problems, message }
  end

  test "a task that could never run as written is refused before it ships, starting with a mistyped schedule" do
    theme_file("globals/figures.yml", title: "Figures", blueprint: { title: "Figures", tabs: { main: { sections: [ { fields: [ { handle: "usd", field: { type: "text" } } ] } ] } } })
    theme_file("tasks/typo.yml", title: "Typo", schedule: "evrey 2 hours", request: { url: "https://hooks.example.test/in" })
    theme_file("tasks/both.yml", title: "Both", schedule: "every hour", handler: "sync", request: { url: "https://hooks.example.test/in" })
    theme_file("tasks/rates.yml", title: "Rates", schedule: "every 2 hours",
                                  fetch: { use: "rates", into: { global: "figures", map: { usd: "{response.usd}", gbp: "{response.gbp}" } } })
    theme_file("tasks/sync.yml", title: "Sync", schedule: "*/5 * * * *", handler: "missing.handler")
    theme_file("tasks/fine.yml", title: "Fine", schedule: "at 5am every day", fetch: { url: "https://api.example.test/rates", into: { global: "figures", map: { usd: "{response.usd}" } } })

    problems = check.problems.map(&:to_s).join("\n")
    [
      "tasks/typo.yml: schedule 'evrey 2 hours' isn't a schedule Nibble can read",
      "tasks/both.yml: needs exactly one of fetch, request or handler",
      "tasks/rates.yml: fetch uses the API connection 'rates', which isn't in the schema",
      "tasks/rates.yml: fetch.into.map names 'gbp', which global figures doesn't have",
      "tasks/sync.yml: handler 'missing.handler' isn't registered"
    ].each { |message| assert_includes problems, message }
    assert_not_includes problems, "tasks/fine.yml"
  end

  test "a collection or taxonomy icon must be one of the Control Plane icons, so the sidebar never shows a blank" do
    theme_file("taxonomies/people.yml", title: "People", blueprints: [ "person" ], icon: "user-avatar")
    theme_file("blueprints/taxonomies/people/person.yml", title: "Person", tabs: { main: { sections: [ { fields: [ { handle: "title", field: { type: "text" } } ] } ] } })
    theme_file("taxonomies/places.yml", title: "Places", blueprints: [ "place" ], icon: "../secrets")
    theme_file("blueprints/taxonomies/places/place.yml", title: "Place", tabs: { main: { sections: [ { fields: [ { handle: "title", field: { type: "text" } } ] } ] } })

    problems = check.problems.map(&:to_s).join("\n")
    assert_includes problems, "icon '../secrets' isn't one of the Control Plane icons"
    assert_not_includes problems, "icon 'user-avatar'"

    schema = Nibble::Schema.load(Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes))
    icons = Nibble::Cp::Navigation.for(users(:admin), schema:).flat_map { |section| section["items"] }.to_h { |item| [ item["title"], item["icon"] ] }
    assert_equal "user-avatar", icons["People"]
  end

  test "a public file field is held to hard limits and can never accept dangerous types" do
    theme_file("forms/upload.yml", title: "Upload", store: false, fields: [
      { handle: "cv", field: { type: "files", max_files: 50, max_file_size: 100, extensions: %w[pdf html svg] } }
    ])

    problems = check.problems.map(&:to_s).join("\n")
    [
      "field 'cv' needs the form to store submissions, which is where its files are kept",
      "field 'cv' max_files must be between 1 and 10",
      "field 'cv' max_file_size must be between 1 and 25 MB",
      "field 'cv' can't accept html, svg files from the public"
    ].each { |message| assert_includes problems, message }
  end

  test "a complete form passes, with safe defaults for the honeypot, rate limit and delivery mode" do
    theme_file("apis/crm.yml", base_url: "https://crm.example.test")
    theme_file("forms/contact.yml", title: "Contact", fields: [ { handle: "email", field: { type: "text", input_type: "email" } } ],
      api: [ { use: "crm" } ], notify: [ { to: "team@example.test" } ], success: { message: "Thanks!" }, retention_days: 90)

    form_problems = check.problems.select { |problem| problem.source.include?("forms/") }
    assert_empty form_problems, form_problems.map(&:to_s).join("\n")
    form = Nibble::Forms::Form.new(item: Nibble::Schema.load(Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes)).find(:forms, "contact"))
    assert_equal [ "_nibble_hp", { "requests" => 5, "per_minutes" => 1 }, "async" ], [ form.honeypot, form.rate_limit, form.deliveries.first["mode"] ]
  end

  test "problems inside nested sets are found, not only top-level fields" do
    theme_file("fieldsets/broken_blocks.yml", title: "Broken", fields: [
      { handle: "blocks", field: { type: "replicator", sets: { hero: { fields: [ { handle: "title", field: { type: "text", charcter_limit: 5 } } ] } } } }
    ])

    assert_match "charcter_limit: isn't an option of the text fieldtype", check.problems.map(&:to_s).join("\n")
  end

  test "unknown validation rules, reserved entry handles and bad references are all reported together" do
    theme_file("collections/events.yml", title: "Events", blueprints: [ "event" ])
    theme_file("blueprints/collections/events/event.yml", title: "Event", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text", validate: [ "postcode" ] } },
      { handle: "slug", field: { type: "slug" } }
    ] } ] } })
    theme_file("navigation/events.yml", title: "Events", collections: [ "evnts" ])

    messages = check.problems.map(&:to_s).join("\n")
    assert_match "unknown validation rule 'postcode'", messages
    assert_match "field handle 'slug' is reserved", messages
    assert_match "collection 'evnts' doesn't exist", messages
  end

  test "a schema that doesn't load is reported instead of raising" do
    theme_file("collections/broken.yml", "title: [unclosed")
    result = check
    assert_not result.ok?
    assert_match "invalid YAML", result.problems.first.to_s
  end

  test "view sidecar queries are validated against the schema" do
    view = @themes.join("check", "views", "posts", "index.yml")
    FileUtils.mkdir_p(view.dirname)
    view.write({ "posts" => { "from" => "entries:posts", "where" => { "excerpt" => "x" } } }.to_yaml)

    assert_match "query 'posts' where.excerpt: isn't filterable", check.problems.map(&:to_s).join("\n")
  end

  test "a sidecar may take limit and per_page from its block" do
    view = @themes.join("check", "views", "sets", "latest.yml")
    FileUtils.mkdir_p(view.dirname)
    view.write({ "posts" => { "from" => "entries:posts", "limit" => "$set.count" }, "paged" => { "from" => "entries:posts", "paginate" => { "per_page" => "$set.per_page" } } }.to_yaml)

    assert_not_includes check.problems.map(&:to_s).join("\n"), "latest.yml"
  end

  # A list that is no longer read would otherwise drop collections from search without a word.
  test "from 0.17.0 a search.yml that lists collections is reported, naming the key that replaces it" do
    theme_file("search.yml", { schema: 1, indexes: { site: { collections: [ "pages" ] } } })
    config = ->(defaults) { Nibble::Config.new({ "theme" => "check", "load_defaults" => defaults, "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes, site_schema_path: @themes.join("no_site_schema")) }

    messages = Nibble::Check.run(config: config.("0.17.0"), static: true).problems.map(&:message)
    assert_includes messages, "index 'site' lists collections, which are no longer read: give each one `search: site` in its own file"

    messages = Nibble::Check.run(config: config.("0.16.1"), static: true).problems.map(&:message)
    assert_not(messages.any? { |message| message.include?("no longer read") })
  end
end

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

  test "messages must belong to a rule the field has, and name locales the site has" do
    theme_file("forms/signup.yml", title: "Signup", success: { message: "Thanks!" }, fields: [
      { handle: "phone", field: { type: "text", validate: [ "regex:/^04/" ], messages: { regex: { en: "Mobile please", fr: "Mobile" }, min: "Too short" } } },
      { handle: "name", field: { type: "text", required: true, messages: { required: "Say who you are" } } }
    ])

    messages = check.problems.map(&:to_s).grep(/phone|name/)

    assert_equal 2, messages.size
    assert(messages.any? { |m| m.include?("message for 'min'") })
    assert(messages.any? { |m| m.include?("'regex' message for locale 'fr'") })
  end

  test "a required condition holds one condition key and names fields beside it" do
    theme_file("forms/signup.yml", title: "Signup", success: { message: "Thanks!" }, fields: [
      { handle: "by", field: { type: "text" } },
      { handle: "good", field: { type: "text", required: { if: { by: "phone" } } } },
      { handle: "none", field: { type: "text", required: {} } },
      { handle: "two", field: { type: "text", required: { if: { by: "phone" }, unless: { by: "email" } } } },
      { handle: "stray", field: { type: "text", required: { if: { nope: "x" } } } }
    ])

    messages = check.problems.map(&:to_s).grep(/required condition/)

    assert_equal 3, messages.size
    assert(messages.none? { |m| m.include?("'good'") })
    assert(messages.any? { |m| m.include?("'stray'") && m.include?("'nope'") })
  end

  test "a step message belongs to an integer field with a step and no other" do
    theme_file("forms/signup.yml", title: "Signup", success: { message: "Thanks!" }, fields: [
      { handle: "amount", field: { type: "integer", step: 5, messages: { step: "In fives" } } },
      { handle: "plain", field: { type: "integer", messages: { step: "In fives" } } },
      { handle: "word", field: { type: "text", messages: { step: "In fives" } } }
    ])

    messages = check.problems.map(&:to_s).grep(/message for 'step'/)

    assert_equal 2, messages.size
    assert(messages.none? { |m| m.include?("amount") })
  end

  test "a message that isn't a string is refused" do
    theme_file("forms/signup.yml", title: "Signup", success: { message: "Thanks!" }, fields: [
      { handle: "phone", field: { type: "text", validate: [ "regex:/^04/" ], messages: { regex: 5 } } }
    ])

    assert(check.problems.any? { |problem| problem.to_s.include?("messages") && problem.to_s.include?("invalid value") })
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
    ], spam: { honeypot: "website", captcha: "turnstile", rate_limit: { requests: 0 }, retention_days: 0 },
      api: [ { use: "crm" }, { url: "ftp://example.test", mode: "later" } ], notify: [ { subject: "New" }, { to: "team@example.test", fields: [ "phone" ], reply_to: "phone" } ],
      handler: "crm.missing", success: { redirect: "thanks" })

    result = check
    problems = result.problems.map(&:to_s).join("\n")
    assert_includes result.warnings.map(&:to_s).join("\n"), "spam.honeypot 'website' looks like a field browsers and password managers fill in",
      "autofill would fill a honeypot called website and throw real enquiries away"
    [
      "field 'related' uses 'entries', which can't be used on a public form",
      "field handle 'website' clashes with the honeypot",
      "spam.rate_limit needs positive requests and per_minutes",
      "spam.captcha must be true or false",
      "spam.retention_days must be a positive number of days",
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

  test "only a stored form's values can be encrypted, and never a files field, whose files live outside the submission" do
    theme_file("forms/vault.yml", title: "Vault", fields: [
      { handle: "phone", field: { type: "text", encrypt: true } },
      { handle: "cv", field: { type: "files", encrypt: true } }
    ])
    theme_file("forms/passing.yml", title: "Passing", store: false, fields: [ { handle: "phone", field: { type: "text", encrypt: true } } ])

    problems = check.problems.map(&:to_s).join("\n")
    assert_includes problems, "forms/vault.yml: field 'cv' can't be encrypted: a files field keeps its files in storage, not in the submission"
    assert_includes problems, "forms/passing.yml: field 'phone' has `encrypt: true` but the form has `store: false`, so nothing is stored to encrypt"
    assert_not_includes problems, "field 'phone' can't be encrypted"
  end

  test "the timing and link spam checks take whole numbers, and stay off unless set" do
    theme_file("forms/odd.yml", title: "Odd", fields: [ { handle: "email", field: { type: "text" } } ], spam: { min_seconds: 0, max_links: -1 })
    theme_file("forms/set.yml", title: "Set", fields: [ { handle: "email", field: { type: "text" } } ], spam: { min_seconds: 3, max_links: 0 })

    problems = check.problems.map(&:to_s).join("\n")
    assert_includes problems, "forms/odd.yml: spam.min_seconds must be a positive whole number of seconds"
    assert_includes problems, "forms/odd.yml: spam.max_links must be a whole number, 0 or more"
    assert_not_includes problems, "set.yml"
  end

  test "a form's limits must be ones Nibble can enforce: real times in order, a positive cap, and unique fields it can compare" do
    fields = [ { handle: "email", field: { type: "text" } }, { handle: "topics", field: { type: "checkboxes", options: %w[a b] } } ]
    theme_file("forms/broken.yml", title: "Broken", fields:, limits: { max_submissions: 0, opens_at: "next week", closes_at: "2026-11-01T09:00",
                                                                       unique: [ "topics" ], closed_message: 5, seats: 3 })
    theme_file("forms/backwards.yml", title: "Backwards", store: false, fields:,
                                      limits: { opens_at: "2026-11-02T09:00", closes_at: "2026-11-01T09:00", max_submissions: 10, unique: [ "email" ] })
    theme_file("forms/fine.yml", title: "Fine", fields:,
                                 limits: { opens_at: "2026-11-01T09:00", closes_at: "2026-11-02", max_submissions: 100, unique: [ "email" ], closed_message: "Full." })

    problems = check.problems.map(&:to_s).join("\n")
    [
      "forms/broken.yml: limits.seats isn't a limit; use max_submissions, opens_at, closes_at, closed_message or unique",
      "forms/broken.yml: limits.max_submissions must be a positive whole number",
      "forms/broken.yml: limits.opens_at must be a quoted date and time like \"2026-11-01T09:00\"",
      "forms/broken.yml: limits.unique must list the form's text, number, single-choice or date fields",
      "forms/broken.yml: limits.closed_message must be text",
      "forms/backwards.yml: limits.closes_at must be after limits.opens_at",
      "forms/backwards.yml: limits.max_submissions needs the form to store submissions, which is what it counts against",
      "forms/backwards.yml: limits.unique needs the form to store submissions, which is what it counts against"
    ].each { |message| assert_includes problems, message }
    assert_not_includes problems, "fine.yml"
  end

  test "a complete form passes, with safe defaults for the honeypot, rate limit and delivery mode" do
    theme_file("apis/crm.yml", base_url: "https://crm.example.test")
    theme_file("forms/contact.yml", title: "Contact", fields: [ { handle: "email", field: { type: "text", input_type: "email" } } ],
      api: [ { use: "crm" } ], notify: [ { to: "team@example.test" } ], success: { message: "Thanks!" }, retention_days: 90)

    form_problems = check.findings.select { |problem| problem.source.include?("forms/") }
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

  test "a set without a view is a warning, because its blocks render nothing" do
    theme_file("collections/events.yml", title: "Events", blueprints: [ "event" ])
    theme_file("blueprints/collections/events/event.yml", title: "Event", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } },
      { handle: "blocks", field: { type: "replicator", sets: { hero: { fields: [ { handle: "title", field: { type: "text" } } ] } } } }
    ] } ] } })
    @themes.join("check", "theme.yml").write("name: Check\n")

    result = check
    assert(result.warnings.any? { |warning| warning.message.include?("set 'hero' has no view sets/hero.vue") })
    assert_not(result.problems.any? { |problem| problem.message.include?("set 'hero'") })
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

  test "a routed collection whose entries resolve to a view the theme lacks warns, and one with a template that exists does not" do
    theme_file("collections/events.yml", title: "Events", route: "/events/{slug}", blueprints: [ "event" ])
    theme_file("blueprints/collections/events/event.yml", title: "Event", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } }
    ] } ] } })
    @themes.join("check", "theme.yml").write("name: Check\n")

    warning = check.warnings.find { |item| item.source.end_with?("collections/events.yml") }
    assert_match "default.vue", warning.message

    theme_file("collections/events.yml", title: "Events", route: "/events/{slug}", template: "pages/show", blueprints: [ "event" ])
    FileUtils.mkdir_p(@themes.join("check", "views", "pages"))
    FileUtils.touch(@themes.join("check", "views", "pages", "show.vue"))
    assert_nil check.warnings.find { |item| item.source.end_with?("collections/events.yml") }
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

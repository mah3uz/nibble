require "test_helper"

class Nibble::CheckTest < ActiveSupport::TestCase
  setup { @themes = Pathname(Dir.mktmpdir("nibble-themes")) }
  teardown { FileUtils.rm_rf(@themes) }

  def theme_file(relative, content)
    path = @themes.join("check", "schema", relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(content.is_a?(String) ? content : content.deep_stringify_keys.to_yaml)
  end

  def check(theme: "check")
    config = Nibble::Config.new({ "theme" => theme, "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes)
    Nibble::Check.run(config:)
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

  test "a collection or taxonomy icon must be one of the admin icons, so the sidebar never shows a blank" do
    theme_file("taxonomies/people.yml", title: "People", blueprints: [ "person" ], icon: "user-avatar")
    theme_file("blueprints/taxonomies/people/person.yml", title: "Person", tabs: { main: { sections: [ { fields: [ { handle: "title", field: { type: "text" } } ] } ] } })
    theme_file("taxonomies/places.yml", title: "Places", blueprints: [ "place" ], icon: "../secrets")
    theme_file("blueprints/taxonomies/places/place.yml", title: "Place", tabs: { main: { sections: [ { fields: [ { handle: "title", field: { type: "text" } } ] } ] } })

    problems = check.problems.map(&:to_s).join("\n")
    assert_includes problems, "icon '../secrets' isn't one of the admin icons"
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
end

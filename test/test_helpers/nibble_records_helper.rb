module NibbleRecordsHelper
  SCHEMA = {
    "collections/articles.yml" => {
      title: "Articles", route: "/articles/{year}/{slug}", dated: true, expires: true, blueprints: [ "article" ],
      taxonomies: [ "tags" ], revisions: { keep: 3 }, api: true
    },
    "blueprints/collections/articles/article.yml" => { title: "Article", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text", required: true } },
      { handle: "summary", field: { type: "textarea", validate: [ "max:20" ] } },
      { handle: "seats", field: { type: "integer", min: 10, step: 5 } },
      { handle: "related", field: { type: "entries", collections: [ "articles", "docs" ] } },
      { handle: "tags", field: { type: "terms", taxonomies: [ "tags" ] } },
      { handle: "image", field: { type: "assets", max_files: 1, preset: "card" } },
      { handle: "blocks", field: { type: "replicator", sets: {
        quote: { fields: [ { handle: "source", field: { type: "entries" } } ] },
        rich_text: { fields: [ { handle: "text", field: { type: "rich_text" } } ] },
        columns: { fields: [ { handle: "cells", field: { type: "grid", fields: [ { handle: "body", field: { type: "rich_text" } } ] } },
                             { handle: "inner", field: { type: "replicator", sets: { rich_text: { fields: [ { handle: "text", field: { type: "rich_text" } } ] } } } } ] }
      } } }
    ] } ] } } },
    "collections/docs.yml" => { title: "Docs", route: "{parent_uri}/{slug}", structure: { max_depth: 3 }, blueprints: [ "doc" ],
                                taxonomies: [ "tags" ], workflow: "review" },
    "blueprints/collections/docs/doc.yml" => { title: "Doc", tabs: {
      main: { sections: [ { fields: [
        { handle: "title", field: { type: "text", required: true } },
        { handle: "body", field: { type: "textarea", required: true } }
      ] } ] },
      sidebar: { display: "Sidebar", sections: [ { fields: [ { handle: "byline", field: { type: "text" } } ] } ] }
    } },
    "taxonomies/tags.yml" => { title: "Tags", route: "/tags/{slug}", blueprints: [ "tag" ], api: true },
    "blueprints/taxonomies/tags/tag.yml" => { title: "Tag", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text", required: true } }
    ] } ] } } },
    "blueprints/assets/asset.yml" => { title: "Asset", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } }, { handle: "alt", field: { type: "text" } },
      { handle: "caption", field: { type: "textarea" } }, { handle: "credit", field: { type: "text" } },
      { handle: "license", field: { type: "select", options: %w[cc0 rights_reserved] } }
    ] } ] } } },
    "forms/contact.yml" => { title: "Contact", retention_days: 30, success: { message: "Thanks, we'll be in touch." }, fields: [
      { handle: "name", field: { type: "text", required: true } },
      { handle: "email", field: { type: "text", input_type: "email", required: true } },
      { handle: "topic", field: { type: "select", options: { sales: "Sales team", support: "Support" } } },
      { handle: "message", field: { type: "textarea", required: true, validate: [ "max:500" ] } }
    ] },
    "forms/callback.yml" => { title: "Callback", store: false, fields: [
      { handle: "phone", field: { type: "text", validate: [ "regex:/^04\\d{8}$/" ], messages: { regex: "Enter an Australian mobile number" } } }
    ] },
    "forms/signup.yml" => { title: "Signup", store: false, spam: { captcha: true }, success: { redirect: "/thanks" },
                            fields: [ { handle: "email", field: { type: "text", input_type: "email", required: true } } ] },
    "apis/crm.yml" => { base_url: "https://crm.example.test/v1", headers: { Authorization: "Bearer {secret.crm_token}" },
                        errors: { status: [ 422 ], path: "errors" }, retry: { attempts: 3, backoff_seconds: 10 } },
    "forms/lead.yml" => { title: "Lead", fields: [ { handle: "email", field: { type: "text", input_type: "email", required: true } } ],
                          api: [ { use: "crm", path: "/leads", mode: "sync", body: { email_address: "{field.email}", source: "web" },
                                   error_fields: { email_address: "email" } },
                                 { url: "https://hooks.example.test/in", mode: "async" } ] },
    "forms/quick.yml" => { title: "Quick", store: false, fields: [ { handle: "email", field: { type: "text" } } ],
                           api: [ { url: "https://hooks.example.test/quick" } ] },
    "forms/enquiry.yml" => { title: "Enquiry", cp_notify: true, handler: "test.enquiry",
                             notify: [ { to: "sales@example.test", reply_to: "email" },
                                       { to: [ "a@example.test", "b@example.test" ], subject: "Topics", fields: [ "topics" ] } ],
                             fields: [ { handle: "email", field: { type: "text", input_type: "email" } },
                                       { handle: "topics", field: { type: "checkboxes", options: %w[sales support] } },
                                       { handle: "message", field: { type: "textarea" } } ] },
    "forms/application.yml" => { title: "Application", fields: [
      { handle: "name", field: { type: "text" } },
      { handle: "cv", field: { type: "files", required: true, max_files: 2, max_file_size: 1, extensions: %w[pdf docx csv png] } }
    ] },
    "forms/visit.yml" => { title: "Visit", success: { message: "See you." }, sections: [
      { display: "Your details", instructions: "So we can greet you.", fields: [
        { handle: "name", field: { type: "text", required: true } },
        { handle: "budget", field: { type: "integer", prepend: "$", append: "per head" } }
      ] },
      { display: "The visit", fields: [ { handle: "note", field: { type: "textarea" } } ] }
    ] },
    "forms/pledge.yml" => { title: "Pledge", fields: [
      { handle: "amount", field: { type: "integer", min: 2000, max: 10_000, step: 500 } }
    ] },
    "forms/settings.yml" => { title: "Settings", fields: [
      { handle: "email", field: { type: "text", input_type: "email", autocomplete: "email" } },
      { handle: "message", field: { type: "textarea", rows: 8 } },
      { handle: "agree", field: { type: "toggle", inline_label: "I agree to the terms", default: true } },
      { handle: "arrival", field: { type: "date", time_enabled: true, earliest_date: "2026-01-01", latest_date: "2030-12-31", default: "computed:today" } },
      { handle: "topics", field: { type: "select", multiple: true, max_items: 2, clearable: true, options: %w[a b c] } }
    ] },
    "forms/conditional.yml" => { title: "Conditional", fields: [
      { handle: "kind", field: { type: "select", options: %w[personal business] } },
      { handle: "company", field: { type: "text", required: true, if: { kind: "business" } } },
      { handle: "seats", field: { type: "integer", show_when_any: { kind: "is business", company: "contains Ltd" } } },
      { handle: "note", field: { type: "text", unless: { kind: [ "isnt personal", "empty" ] } } },
      { handle: "vip", field: { type: "toggle", if: "custom vip_only:gold" } }
    ] },
    "forms/tracked.yml" => { title: "Tracked", spam: { rate_limit: { requests: 2, per_minutes: 10 } }, fields: [
      { handle: "name", field: { type: "text", required: true } },
      { handle: "source", field: { type: "text", hidden: true, prefill: { query: "utm_source" }, validate: [ "max:10" ] } },
      { handle: "channel", field: { type: "text", hidden: true, value: "web" } },
      { handle: "campaign", field: { type: "text", hidden: true, prefill: { query: "utm_campaign" }, value: "organic" } }
    ] },
    "forms/worded_pledge.yml" => { title: "Worded pledge", fields: [
      { handle: "amount", field: { type: "integer", min: 2000, step: 500, messages: { step: { en: "Steps of $%{step} from $%{min}", fr: "Par tranches de %{step}" } } } }
    ] },
    "navigation/docs_menu.yml" => { title: "Docs menu", max_depth: 2, collections: [ "docs" ] }
  }.freeze

  def self.included(base)
    base.setup { use_nibble_records_schema }
    base.teardown { reset_nibble_records_schema }
  end

  def use_nibble_records_schema
    @nibble_themes = Pathname(Dir.mktmpdir("nibble-records"))
    manifest = @nibble_themes.join("records", "theme.yml")
    FileUtils.mkdir_p(manifest.dirname)
    manifest.write({ "name" => "Records fixture", "handle" => "records", "version" => "1.0.0", "nibble" => "^1" }.to_yaml)
    SCHEMA.each do |relative, content|
      path = @nibble_themes.join("records", "schema", relative)
      FileUtils.mkdir_p(path.dirname)
      path.write(content.deep_stringify_keys.to_yaml)
    end
    configure_nibble_records
    Nibble.reset_schema!
    Nibble.boot!
  end

  def configure_nibble_records(load_defaults: nil, outbound: {}, locales: [ { "code" => "en", "default" => true } ])
    Nibble.config = Nibble::Config.new({ "theme" => "records", "url" => "https://example.com", "load_defaults" => load_defaults, "locales" => locales, "reserved_paths" => [ "/cp" ],
                                         "outbound" => { "secrets" => [ "crm_token" ] }.merge(outbound),
                                         "assets" => { "presets" => { "card" => { "w" => 32, "h" => 16, "fit" => "crop", "srcset" => [ 16, 32 ] } } } },
      themes_path: @nibble_themes, site_schema_path: @nibble_themes.join("site_schema"), agents_path: @nibble_themes.join("agents"))
  end

  def use_site_addresses(values = {})
    path = @nibble_themes.join("records", "schema", "globals", "site.yml")
    FileUtils.mkdir_p(path.dirname)
    path.write({ "title" => "Site", "blueprint" => { "title" => "Site", "tabs" => { "main" => { "sections" => [ { "fields" => [
      { "handle" => "name", "field" => { "type" => "text" } },
      { "handle" => "apply_url", "field" => { "type" => "text", "input_type" => "url" } },
      { "handle" => "booking", "field" => { "type" => "link" } }
    ] } ] } } } }.to_yaml)
    Nibble.reset_schema!
    Nibble::Records::GlobalSet.create!(handle: "site", locale: "en", data: values.deep_stringify_keys)
  end

  def reset_nibble_records_schema
    Nibble.config = nil
    Nibble.reset_schema!
    Nibble.boot!
    FileUtils.rm_rf(@nibble_themes)
  end

  def lifecycle(record, action, attrs = {}, **options)
    keywords = { actor: Nibble::Principal.system }.merge(options.select { |key, _| key.is_a?(Symbol) })
    Nibble::Lifecycle.call(record, action, attrs.merge(options.except(*keywords.keys)), **keywords)
  end

  def create_entry(collection, attrs = {}, actor: Nibble::Principal.system)
    defaults = collection == "docs" ? { "title" => "Doc", "body" => "Body" } : { "title" => "Article" }
    result = lifecycle(Nibble::Records::Entry.new(collection:), :create, defaults.merge(attrs.deep_stringify_keys), actor:)
    assert result.ok?, "create failed: #{result.errors}"
    result.record
  end

  def publish_entry(entry, attrs = {})
    result = lifecycle(entry, :publish, { "published_at" => 1.day.ago.utc.iso8601 }.merge(attrs.deep_stringify_keys))
    assert result.ok?, "publish failed: #{result.errors}"
    entry
  end

  def upload_blob(name = "photo.jpg", **options)
    ActiveStorage::Blob.create_and_upload!(io: file_fixture(name).open, filename: name, **options)
  end

  def create_asset(attrs = {}, blob: upload_blob)
    result = lifecycle(Nibble::Records::Asset.new(blob:), :create, attrs)
    assert result.ok?, "asset create failed: #{result.errors}"
    result.record
  end

  def create_term(title, taxonomy: "tags")
    result = lifecycle(Nibble::Records::Term.new(taxonomy:), :create, "title" => title)
    assert result.ok?, "term create failed: #{result.errors}"
    result.record
  end
end

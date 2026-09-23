module NibbleRecordsHelper
  SCHEMA = {
    "collections/articles.yml" => {
      title: "Articles", route: "/articles/{year}/{slug}", dated: true, expires: true, blueprints: [ "article" ],
      taxonomies: [ "tags" ], revisions: { keep: 3 }, api: true
    },
    "blueprints/collections/articles/article.yml" => { title: "Article", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text", required: true } },
      { handle: "summary", field: { type: "textarea", validate: [ "max:20" ] } },
      { handle: "related", field: { type: "entries", collections: [ "articles", "docs" ] } },
      { handle: "tags", field: { type: "terms", taxonomies: [ "tags" ] } },
      { handle: "image", field: { type: "assets", max_files: 1, preset: "card" } },
      { handle: "blocks", field: { type: "replicator", sets: { quote: { fields: [ { handle: "source", field: { type: "entries" } } ] } } } }
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

  def configure_nibble_records(load_defaults: nil)
    Nibble.config = Nibble::Config.new({ "theme" => "records", "load_defaults" => load_defaults, "locales" => [ { "code" => "en", "default" => true } ], "reserved_paths" => [ "/admin" ],
                                         "outbound" => { "secrets" => [ "crm_token" ] },
                                         "assets" => { "presets" => { "card" => { "w" => 32, "h" => 16, "fit" => "crop", "srcset" => [ 16, 32 ] } } } },
      themes_path: @nibble_themes, site_schema_path: @nibble_themes.join("site_schema"))
  end

  def reset_nibble_records_schema
    Nibble.config = nil
    Nibble.reset_schema!
    Nibble.boot!
    FileUtils.rm_rf(@nibble_themes)
  end

  def lifecycle(record, action, attrs = {}, **options)
    keywords = options.select { |key, _| key.is_a?(Symbol) }
    Nibble::Lifecycle.call(record, action, attrs.merge(options.except(*keywords.keys)), **keywords)
  end

  def create_entry(collection, attrs = {}, actor: nil)
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

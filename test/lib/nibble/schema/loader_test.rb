require "test_helper"

class Nibble::Schema::LoaderTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir("nibble-schema"))
    @core = @root.join("core")
    @theme = @root.join("theme")
    @site = @root.join("site")
  end

  teardown { FileUtils.rm_rf(@root) }

  def write(layer, relative, data)
    path = layer.join(relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(data.is_a?(String) ? data : data.to_yaml)
  end

  def load(disabled: [])
    items = Nibble::Schema::Loader.new(layers: [ [ :core, @core ], [ :theme, @theme ], [ :site, @site ] ], disabled:).load
    Nibble::Schema.new(items)
  end

  def posts_collection(**extra)
    { "title" => "Posts", "route" => "/blog/{slug}", "blueprints" => [ "post" ] }.merge(extra.stringify_keys)
  end

  def blueprint(title = "Post")
    { "title" => title, "tabs" => { "main" => { "sections" => [ { "fields" => [] } ] } } }
  end

  test "a theme file replaces the core file whole, so what the file says is exactly what applies" do
    write(@core, "collections/posts.yml", posts_collection(dated: true, sort: "published_at:desc"))
    write(@core, "blueprints/collections/posts/post.yml", blueprint)
    write(@theme, "collections/posts.yml", posts_collection(route: "/{slug}"))

    posts = load.collection("posts")
    assert_equal "/{slug}", posts["route"]
    assert_nil posts["dated"], "core keys must not leak into a replacement"
    assert_equal :theme, posts.layer
  end

  test "the site layer overrides the theme so operators customise without forking it" do
    write(@core, "collections/posts.yml", posts_collection)
    write(@core, "blueprints/collections/posts/post.yml", blueprint)
    write(@theme, "blueprints/collections/posts/post.yml", blueprint("Theme post"))
    write(@site, "blueprints/collections/posts/post.yml", blueprint("Site post"))

    schema = load
    post = schema.blueprint(schema.collection("posts"), "post")
    assert_equal "Site post", post["title"]
    assert_equal :site, post.layer
  end

  test "core fieldsets are namespaced so a theme fieldset with the same name can't shadow them" do
    write(@core, "fieldsets/seo.yml", { "title" => "Core SEO", "fields" => [] })
    write(@theme, "fieldsets/seo.yml", { "title" => "Theme SEO", "fields" => [] })

    schema = load
    assert_equal "Core SEO", schema.fieldset("nibble::seo")["title"]
    assert_equal "Theme SEO", schema.fieldset("seo")["title"]
  end

  test "disabling a collection also removes its blueprints, and core fieldsets can't be disabled" do
    write(@core, "collections/posts.yml", posts_collection)
    write(@core, "blueprints/collections/posts/post.yml", blueprint)
    write(@core, "fieldsets/seo.yml", { "title" => "SEO", "fields" => [] })

    schema = load(disabled: [ "collections/posts" ])
    assert_nil schema.collection("posts")
    assert_empty schema.all(:blueprints)

    assert_raises(Nibble::SchemaError, match: /core-owned/) { load(disabled: [ "fieldsets/nibble::seo" ]) }
    assert_raises(Nibble::SchemaError, match: /doesn't exist/) { load(disabled: [ "collections/nope" ]) }
  end

  test "unknown keys fail with the file and key, so typos never silently do nothing" do
    write(@core, "collections/posts.yml", posts_collection(routes: "/blog/{slug}"))
    error = assert_raises(Nibble::SchemaError) { load }
    assert_match %r{collections/posts\.yml: routes: unknown key}, error.message
  end

  test "invalid values and missing required keys are rejected" do
    write(@core, "collections/posts.yml", posts_collection(workflow: "sometimes"))
    assert_raises(Nibble::SchemaError, match: /workflow: has an invalid value/) { load }

    write(@core, "collections/posts.yml", { "title" => "Posts" })
    assert_raises(Nibble::SchemaError, match: /blueprints: is required/) { load }
  end

  test "a collection must point at blueprints and taxonomies that exist" do
    write(@core, "collections/posts.yml", posts_collection(taxonomies: [ "topics" ]))
    write(@core, "blueprints/collections/posts/post.yml", blueprint)
    assert_raises(Nibble::SchemaError, match: /taxonomies\.0: no taxonomy 'topics'/) { load }

    write(@core, "collections/posts.yml", posts_collection(blueprints: [ "post", "gallery" ]))
    assert_raises(Nibble::SchemaError, match: %r{blueprints\.1: no blueprint at blueprints/collections/posts/gallery\.yml}) { load }
  end

  test "a blueprint for an undefined collection is an error, not an orphan" do
    write(@theme, "blueprints/collections/events/event.yml", blueprint("Event"))
    assert_raises(Nibble::SchemaError, match: /belongs to collections\/events/) { load }
  end

  test "files from a newer schema format are refused instead of misread" do
    write(@core, "collections/posts.yml", posts_collection.merge("schema" => 2))
    assert_raises(Nibble::SchemaError, match: /format 2 isn't supported/) { load }
  end

  test "misplaced files and reserved handle characters are rejected" do
    write(@theme, "widgets/thing.yml", { "title" => "x" })
    assert_raises(Nibble::SchemaError, match: /unknown schema folder 'widgets'/) { load }
    FileUtils.rm_rf(@theme)

    write(@theme, "blueprints/posts/post.yml", blueprint)
    assert_raises(Nibble::SchemaError, match: /blueprints live at/) { load }
    FileUtils.rm_rf(@theme)

    write(@theme, "fieldsets/nibble::seo.yml", { "title" => "x", "fields" => [] })
    assert_raises(Nibble::SchemaError, match: /can't contain '::'/) { load }
  end

  test "assets have one blueprint that a later layer replaces, since there are no asset containers" do
    write(@core, "blueprints/assets/asset.yml", blueprint("Asset"))
    write(@site, "blueprints/assets/asset.yml", blueprint("Site asset"))
    assert_equal "Site asset", load.find(:blueprints, "assets/asset")["title"]

    write(@theme, "blueprints/assets/photo.yml", blueprint)
    assert_raises(Nibble::SchemaError, match: /blueprints live at/) { load }
  end

  test "blueprints come back in the order the collection lists them, first is the default" do
    write(@core, "collections/pages.yml", { "title" => "Pages", "blueprints" => [ "page", "home" ] })
    write(@core, "blueprints/collections/pages/home.yml", blueprint("Home"))
    write(@core, "blueprints/collections/pages/page.yml", blueprint("Page"))

    schema = load
    assert_equal %w[Page Home], schema.blueprints_for(schema.collection("pages")).map { |b| b["title"] }
  end

  test "the digest changes when any effective schema content changes" do
    write(@core, "fieldsets/seo.yml", { "title" => "SEO", "fields" => [] })
    before = load.digest
    write(@core, "fieldsets/seo.yml", { "title" => "Search", "fields" => [] })
    assert_not_equal before, load.digest
  end

  test "invalid YAML is reported with its file" do
    write(@core, "collections/posts.yml", "title: [unclosed")
    assert_raises(Nibble::SchemaError, match: %r{collections/posts\.yml: invalid YAML}) { load }
  end
end

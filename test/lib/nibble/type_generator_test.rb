require "test_helper"

class Nibble::TypeGeneratorTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def generated = Nibble::TypeGenerator.new.generate

  test "blueprint interfaces extend the presented record shape, so views type-check against real props" do
    assert_match "export interface PostsPost extends RecordBase {\n  collection: 'posts'", generated
    assert_match "topics: TermSummary[]", generated
  end

  test "sidecar queries become typed view props, narrowed by fields and wrapped when paginated" do
    assert_match "'taxonomies/show': {\n    posts: Paginated<(PostsPost)>", generated
    assert_match "more: Pick<(PostsPost), 'title' | 'uri' | 'id' | 'type' | 'url'>[]", generated
    assert_match "topics: Pick<(TopicsTopic),", generated
  end

  # An included field holds whole records, so a view reading the related record's own fields type-checks.
  test "an included field is typed as the records it points at, not their summaries" do
    assert_match "'posts/index': {\n    posts: Paginated<(Omit<PostsPost, 'topics'> & { topics: (TopicsTopic)[] })>", generated
    assert_match "latest: Pick<(Omit<PostsPost, 'topics'> & { topics: (TopicsTopic)[] }), 'title' | 'excerpt' | 'topics'", generated
  end

  test "children are typed one level down, with the same fields and no includes" do
    with_copied_theme do |types, _|
      types.dirname.join("starter/views/home.yml").write(
        { "menu" => { "from" => "entries:pages", "include" => %w[children], "fields" => %w[title] } }.to_yaml
      )
      Nibble.reset_schema!

      assert_match "menu: (Pick<(PagesPage), 'title' | 'id' | 'type' | 'uri' | 'url'> & { children: Pick<(PagesPage), 'title' | 'id' | 'type' | 'uri' | 'url'>[] })[]", generated
    end
  end

  # Inertia hands a layout the page's props, so a layout types them as a view does, with only the page fields it includes.
  test "layout sidecars become LayoutProps, and page.include types just the included fields" do
    with_copied_theme do |types, _|
      layouts = types.dirname.join("starter/layouts")
      layouts.mkpath
      layouts.join("default.yml").write({ "page" => { "include" => %w[related] }, "footer" => { "from" => "terms:topics", "fields" => %w[title] } }.to_yaml)
      types.dirname.join("starter/views/posts/show.yml").write({ "page" => { "include" => %w[topics children] } }.to_yaml)
      Nibble.reset_schema!

      assert_match "export interface LayoutProps {\n  'default': {\n    page: { related: (PostsPost)[] }\n    footer: Pick<(TopicsTopic), 'title' | 'id' | 'type' | 'uri' | 'url'>[]\n  }\n}", generated
      assert_match "'posts/show': {\n    page: { topics: (TopicsTopic)[]; children: (DocsDoc | PagesPage)[] }\n  }", generated
    end
  end

  # Picking a key the record doesn't have fails to compile, so a view asking for the parent needs it added instead.
  test "a query that asks for the parent gets it beside the picked fields, where it can type-check" do
    with_copied_theme do |types, _|
      types.dirname.join("starter/views/posts/show.yml").write(
        { "more" => { "from" => "entries:posts", "fields" => %w[title parent] } }.to_yaml
      )
      Nibble.reset_schema!

      assert_match "more: (Pick<(PostsPost), 'title' | 'id' | 'type' | 'uri' | 'url'> & { parent: ParentSummary | null })[]", generated
      assert_match "parent?: ParentSummary | null", generated
    end
  end

  test "a term query that counts entries types the count, so a view can show it without a cast" do
    with_copied_theme do |types, _|
      types.dirname.join("starter/views/posts/show.yml").write(
        { "topics" => { "from" => "terms:topics", "counts" => "posts", "fields" => %w[title] } }.to_yaml
      )
      Nibble.reset_schema!

      assert_match "topics: (Pick<(TopicsTopic), 'title' | 'id' | 'type' | 'uri' | 'url'> & { entries_count: number })[]", generated
    end
  end

  test "each form gets a values type keyed by field handle, so a theme's v-model is typed" do
    assert_match "export type ContactFormValues = { email: string; topic: 'sales' | 'support' | ''; attachment: File[]; source: string }", generated
    assert_match "export interface FormValues {\n  'contact': ContactFormValues\n}", generated
  end

  test "a view's form prop carries its values type, so useNibbleForm infers them" do
    assert_match "contact: NibbleForm<ContactFormValues>", generated
  end

  test "form values follow what the browser holds for each field type" do
    with_copied_theme do |types, _|
      types.dirname.join("starter/schema/forms/survey.yml").write(
        { "title" => "Survey", "fields" => [
          { "handle" => "agree", "field" => { "type" => "toggle" } },
          { "handle" => "tags", "field" => { "type" => "checkboxes", "options" => { "a" => "A", "it's" => "B" } } },
          { "handle" => "plan", "field" => { "type" => "radio", "options" => %w[free paid] } },
          { "handle" => "many", "field" => { "type" => "select", "multiple" => true, "options" => %w[x y] } },
          { "handle" => "qty", "field" => { "type" => "integer" } },
          { "handle" => "price", "field" => { "type" => "decimal" } },
          { "handle" => "mood", "field" => { "type" => "range" } },
          { "handle" => "stars", "field" => { "type" => "rating" } },
          { "handle" => "total", "field" => { "type" => "calculation", "formula" => "qty * 2" } }
        ] }.to_yaml
      )
      Nibble.reset_schema!

      assert_match "export type SurveyFormValues = { agree: boolean; tags: ('a' | 'it\\'s')[]; plan: 'free' | 'paid' | ''; many: ('x' | 'y')[]; qty: string | number | null; price: string | number | null; mood: string | number | null; stars: string | number | null; total: string | number | null }", generated
    end
  end

  def with_menu(handle = "main", **extra)
    with_copied_theme do |types, _|
      types.dirname.join("starter/schema/navigation").mkpath
      types.dirname.join("starter/schema/navigation/#{handle}.yml").write(
        { "schema" => 1, "title" => "Menu", "collections" => [ "posts" ], "entry_fields" => [ "title" ], **extra.stringify_keys,
          "item_fields" => [ { "handle" => "icon", "field" => { "type" => "text" } }, { "handle" => "dense", "field" => { "type" => "toggle" } } ],
          "kinds" => { "featured" => { "display" => "Featured", "link" => "required",
                                         "fields" => [ { "handle" => "badge", "field" => { "type" => "integer" } } ] } } }.to_yaml
      )
      Nibble.reset_schema!
      yield
    end
  end

  # A theme that reads item.fields.icon only compiles when the menu's own fields are in the types it imports.
  test "a menu's item fields, entry fields and kinds are typed in its own item type" do
    with_menu do
      assert_match "export type MainNavigationItem =", generated
      assert_match "kind: 'link'; type: NavigationLinkType; url: string; fields: { icon: string | null; dense: boolean }; entry: MainNavigationEntry | null", generated
      assert_match "kind: 'featured'; type: NavigationLinkType; url: string; fields: { icon: string | null; dense: boolean; badge: number | null }", generated
      assert_match "export type MainNavigationEntry = { title: string | null }", generated
    end
  end

  # Headings are opt-in, so a menu that doesn't allow them keeps its url a string and existing themes keep compiling.
  test "a menu without headings types url as a string, and one with them narrows on kind" do
    with_menu do
      assert_no_match "'heading'", generated.slice(/export type MainNavigationItem =.*?\n\n/m)
    end
    with_menu("main", headings: true) do
      assert_match "kind: 'heading'; type: null; url: null;", generated
      assert_match "kind: 'link'; type: NavigationLinkType; url: string;", generated
    end
  end

  test "useNavigation is typed per menu through the generated menu map" do
    with_menu("docs") do
      assert_match "declare module '@nibble/types' {\n  interface NavigationMenus {\n", generated
      assert_match "'docs': DocsNavigationItem", generated
    end
  end

  test "a site with no forms still gets valid form types" do
    with_copied_theme do |types, _|
      FileUtils.rm_rf(types.dirname.join("starter/schema/forms"))
      FileUtils.rm_f(types.dirname.join("starter/views/pages/show.yml"))
      Nibble.reset_schema!

      assert_match "export interface FormValues {\n\n}", generated
    end
  end

  def with_copied_theme
    themes = Pathname(Dir.mktmpdir("nibble-types"))
    FileUtils.cp_r(Rails.root.join("test/nibble_themes/starter"), themes.join("starter"))
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ] },
      themes_path: themes, types_path: themes.join("types.d.ts"), site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"),
      content_path: Rails.root.join("test/nibble_content"))
    Nibble.reset_schema!
    yield themes.join("types.d.ts"), themes.join("starter/schema/blueprints/collections/posts/post.yml")
  ensure
    FileUtils.rm_rf(themes)
  end

  test "types that are out of date are rewritten, so a build never stops on a file it generates" do
    with_copied_theme do |types, _|
      types.dirname.mkpath
      types.write("stale")

      assert_equal types, Nibble::TypeGenerator.write!
      assert_equal generated, types.read
    end
  end

  # Vite watches the theme, so rewriting an identical file would reload every open page for nothing.
  test "types already up to date are left untouched" do
    with_copied_theme do |types, _|
      Nibble::TypeGenerator.write!
      before = types.mtime
      sleep 0.01

      Nibble::TypeGenerator.write!
      assert_equal before, types.mtime
    end
  end

  test "a schema change seen in development rewrites the theme's types without a command" do
    with_copied_theme do |types, blueprint|
      Nibble::TypeGenerator.write!
      blueprint.write(blueprint.read.sub("sections:\n", "sections:\n      - fields:\n          - handle: subtitle\n            field: { type: text }\n"))

      Nibble.schema_changed!
      assert_match "subtitle", types.read, "the field added to the blueprint reaches the types the views compile against"
    end
  end

  test "each collection and taxonomy gets a union of its blueprints, for a view that takes any of them" do
    assert_match(/^export type PostsEntry = PostsPost( \| \w+)*$/, generated)
    assert_match(/^export type TopicsTerm = TopicsTopic( \| \w+)*$/, generated)
  end

  test "a union is left out where its name is already a blueprint's, or the file would declare the name twice" do
    with_copied_theme do |types, blueprint|
      FileUtils.cp(blueprint, blueprint.dirname.join("entry.yml"))
      posts = blueprint.dirname.join("../../../collections/posts.yml")
      posts.write(posts.read.sub("blueprints: [post]", "blueprints: [post, entry]"))
      Nibble.reset_schema!

      generated = Nibble::TypeGenerator.new.generate
      assert_equal 1, generated.scan(/^export interface PostsEntry\b/).size
      assert_no_match(/^export type PostsEntry =/, generated)
    end
  end
end

require "test_helper"

class Nibble::TypeGeneratorTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def generated = Nibble::TypeGenerator.new.generate

  test "blueprint interfaces extend the presented record shape, so views type-check against real props" do
    assert_match "export interface PostsPost extends RecordBase {\n  collection: 'posts'", generated
    assert_match "topics: TermSummary[]", generated
  end

  test "sidecar queries become typed view props, narrowed by fields and wrapped when paginated" do
    assert_match "'posts/index': {\n    posts: Paginated<(PostsPost)>", generated
    assert_match "more: Pick<(PostsPost), 'title' | 'uri' | 'id' | 'type' | 'url'>[]", generated
    assert_match "topics: Pick<(TopicsTopic),", generated
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
end

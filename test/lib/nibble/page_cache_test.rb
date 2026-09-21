require "test_helper"

class Nibble::PageCacheTest < ActiveSupport::TestCase
  setup { Nibble::PageCache.store = ActiveSupport::Cache::MemoryStore.new }
  teardown { Nibble::PageCache.store = nil }

  def write(key, tags) = Nibble::PageCache.write(key, tags, body: "<html>#{key}</html>", content_type: "text/html")

  test "a page is served until any of its tags is purged" do
    write("blog", %w[collection:posts entry:1])
    write("about", %w[entry:2])

    Nibble::PageCache.purge("collection:posts")
    assert_nil Nibble::PageCache.read("blog")
    assert_equal "<html>about</html>", Nibble::PageCache.read("about").body
  end

  test "an evicted tag version is a miss, so eviction can never serve a stale page" do
    write("blog", %w[collection:posts])
    Nibble::PageCache.store.delete("nibble:tagv:collection:posts")

    assert_nil Nibble::PageCache.read("blog")
  end

  test "rebuilding the assets moves the key, so no page is served pointing at hashes that no longer exist" do
    manifests = ViteRuby.config.manifest_paths.select(&:exist?)
    was = manifests.to_h { |path| [ path, path.mtime ] }
    before = Nibble::PageCache.key("/")

    FileUtils.touch(manifests, mtime: Time.now + 1.hour)

    refute_equal before, Nibble::PageCache.key("/"),
      "the HTML names hashed files, so a build that renames them has to invalidate what was cached against them"
  ensure
    was.each { |path, mtime| FileUtils.touch(path, mtime:) }
  end

  test "the asset version follows the build manifest, which is what a rebuild rewrites" do
    newest = ViteRuby.config.manifest_paths.select(&:exist?).map { |path| path.mtime.to_i }.max

    assert_equal newest.to_s, Nibble::PageCache.send(:asset_version)
  end
end

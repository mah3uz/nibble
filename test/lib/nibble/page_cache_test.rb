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
end

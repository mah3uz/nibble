require "test_helper"

class Nibble::PresenterTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  setup { seed_starter_site }

  def present(records, **options) = Nibble::Presenter.present(records, **options)
  def count_queries(&block) = Nibble::QueryCounter.count(&block).last

  test "every record has the same stable base shape, whatever its blueprint" do
    data = present([ @posts[0] ]).first
    assert_equal %w[id uuid type collection blueprint locale title slug uri url status published_at updated_at author], data.keys.first(14)
    assert_equal [ "entry", "posts", "https://example.test/blog/colour-theory" ], data.values_at("type", "collection", "url")
    assert_equal [ { "id" => @design.id.to_s, "type" => "term", "title" => "Design", "uri" => "/topics/design", "url" => "https://example.test/topics/design", "taxonomy" => "topics" } ], data["topics"]
  end

  test "an entry carries its author as a name, which is what a byline needs" do
    author = users(:editor)
    @posts.each { |post| post.update_columns(author_id: author.id) }

    assert_equal({ "id" => author.id, "name" => author.name }, present([ @posts[0] ]).first["author"])
    assert_nil present([ @home ]).first["author"], "a page nobody is recorded against has no byline to show"
  end

  test "authors are loaded once for the whole response, not per entry" do
    @posts.each { |post| post.update_columns(author_id: users(:editor).id) }

    queries = count_queries { present(Nibble::Records::Entry.where(collection: "posts").to_a) }

    assert_operator queries, :<=, 4, "a byline per entry would put the listing back to one query each"
  end

  test "relations are preloaded once for the whole response, not per record" do
    many = present(@posts, include: [ "topics" ])
    queries = count_queries { present(Nibble::Records::Entry.where(collection: "posts").to_a, include: [ "topics" ]) }

    assert_equal 4, many.size
    assert_operator queries, :<=, 2, "one relations query and one query per target type, regardless of how many posts"
  end

  test "images in bodies are loaded with the rest of the page, not one query per image" do
    @posts.each_with_index do |post, index|
      blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo-#{index}.jpg")
      asset = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, {}).record
      body = [ { "type" => "image", "attrs" => { "asset" => asset.id.to_s, "alt" => "Picture #{index}" } } ]
      assert Nibble::Lifecycle.call(post.reload, :publish, { "body" => body, "published_at" => 1.day.ago.utc.iso8601 }).ok?
    end
    first = @posts.first.reload
    one = count_queries { present([ first ]) }

    all = nil
    posts = @posts.map(&:reload)
    queries = count_queries { all = present(posts) }

    assert_equal @posts.size, all.count { |data| data["body"].to_s.include?("<img") }, "every post still renders its image"
    assert_operator queries, :<=, one, "presenting more posts with images costs no more queries"
  end

  test "included relations are presented in full at depth 2, and cycles are cut" do
    grids, colour = @posts[1], @posts[0]
    ok Nibble::Lifecycle.call(grids, :save, { "related" => [ colour.id.to_s ] })
    ok Nibble::Lifecycle.call(grids.reload, :publish)
    ok Nibble::Lifecycle.call(colour, :save, { "related" => [ grids.id.to_s ] })
    ok Nibble::Lifecycle.call(colour.reload, :publish)

    data = present([ grids.reload ], include: [ "related" ]).first
    related = data["related"].first
    assert_equal "Colour theory", related["title"]
    assert_equal [], related["related"], "the path back to the record being presented is cut"
  end

  test "related drafts are hidden from public output" do
    ok Nibble::Lifecycle.call(@posts[0], :save, { "related" => [ @posts[1].id.to_s ] })
    ok Nibble::Lifecycle.call(@posts[0].reload, :publish)
    ok Nibble::Lifecycle.call(@posts[1], :unpublish)

    assert_equal [], present([ @posts[0].reload ]).first["related"]
  end

  test "presenting records collects the tags of everything shown" do
    _, tags = Nibble::Dependencies.track { present([ @posts[3] ]) }
    assert_equal [ "entry:#{@posts[3].id}", "term:#{@culture.id}", "term:#{@design.id}" ].sort, tags.sort
  end

  test "navigation links resolve to live entries and drop the rest" do
    ok Nibble::Lifecycle.call(@about, :unpublish)
    tree = Nibble::Records::NavigationTree.find_by!(handle: "main")

    assert_equal [ "Blog" ], Nibble::Presenter.new(context: Nibble::Query::Context.public).present_navigation(tree).map { |link| link["title"] }
  end
end

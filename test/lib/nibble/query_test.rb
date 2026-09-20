require "test_helper"

class Nibble::QueryTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  setup { seed_starter_site }

  def run_query(spec, **context) = Nibble::Query.build(spec, Nibble::Query::Context.public(**context)).result
  def titles(spec, **context) = run_query(spec, **context).records.map(&:title)

  test "relation operators filter through the relations table: in, all and none" do
    assert_equal [ "Type scales", "Grids", "Colour theory" ], titles({ from: "entries:posts", where: { topics: { in: [ @design.id ] } } })
    assert_equal [ "Type scales" ], titles({ from: "entries:posts", where: { topics: { all: [ @design.id, @culture.id ] } } })
    assert_equal [ "Remote work" ], titles({ from: "entries:posts", where: { topics: { none: [ @design.id ] } } })
  end

  test "column operators, not, sort and limit combine" do
    spec = { from: "entries:posts", where: { published_at: { lte: "$now" }, title: { prefix: "G" } }, not: { id: @posts[0].id }, sort: "title:asc", limit: 5 }
    assert_equal [ "Grids" ], titles(spec)
    assert_equal [ "About", "Blog", "Home" ], titles({ from: "entries:pages", where: { parent_id: { null: true } }, sort: "title:asc" })
  end

  test "variables read from the current entry, term and declared params" do
    grids = @posts[1]
    spec = { from: "entries:posts", where: { topics: "$entry.topics" }, not: { id: "$entry.id" }, sort: "title:asc" }
    assert_equal [ "Colour theory", "Type scales" ], titles(spec, entry: grids)
    assert_equal [ "Remote work", "Type scales" ], titles({ from: "entries:posts", where: { topics: "$term" }, sort: "title:asc" }, term: @culture)
  end

  test "public queries never return drafts or trashed entries" do
    ok Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => "Draft post" })
    ok Nibble::Lifecycle.call(@posts[0], :unpublish)

    assert_equal [ "Type scales", "Remote work", "Grids" ], titles({ from: "entries:posts" })
  end

  test "pagination reports totals and reads its page from the declared param" do
    result = run_query({ from: "entries:posts", paginate: { per_page: 3, param: "p" } }, params: { "p" => "2" })
    assert_equal [ "Colour theory" ], result.records.map(&:title)
    assert_equal({ "current_page" => 2, "per_page" => 3, "total" => 4, "last_page" => 2 }, result.pagination)
  end

  test "column-only field lists don't load the data column, the expensive part of a listing" do
    record = run_query({ from: "entries:posts", fields: %w[title uri], limit: 1 }).records.first
    assert_not record.has_attribute?(:data)
    assert run_query({ from: "entries:posts", fields: %w[title excerpt], limit: 1 }).records.first.has_attribute?(:data)
  end

  test "queries register the collection tag so listings are purged when any entry changes" do
    _, tags = Nibble::Dependencies.track { run_query({ from: "terms:topics" }) }
    assert_equal [ "taxonomy:topics" ], tags
  end

  test "invalid specs fail with the offending key" do
    {
      { from: "entries:nope" } => "from",
      { from: "search:nope", q: "x" } => "from",
      { from: "search:site" } => "q",
      { from: "search:site", q: "x", sort: "title:asc" } => "sort",
      { from: "entries:posts", where: { excerpt: "x" } } => "where.excerpt",
      { from: "entries:posts", where: { title: { like: "x" } } } => "where.title.like",
      { from: "entries:posts", where: { topics: { eq: 1 } } } => "where.topics.eq",
      { from: "entries:posts", paginate: { per_page: 500 } } => "paginate.per_page",
      { from: "entries:posts", sort: "excerpt:asc" } => "sort",
      { from: "entries:posts", include: [ "excerpt" ] } => "include",
      { from: "entries:posts", fields: [ "nope" ] } => "fields",
      { from: "entries:posts", limit: 5, paginate: { per_page: 5 } } => "paginate",
      { from: "entries:posts", order: "x" } => "order"
    }.each do |spec, key|
      error = assert_raises(Nibble::Query::Invalid, spec.inspect) { Nibble::Query::Spec.parse(spec) }
      assert_equal key, error.key, spec.inspect
    end
  end
end

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

  test "a blueprint field sorts as well as a column, so a collection can order on what it actually holds" do
    %w[delta alpha charlie bravo].each_with_index do |excerpt, index|
      @posts[index].update_columns(data: @posts[index].data.merge("excerpt" => excerpt))
    end

    assert_equal [ "Grids", "Type scales", "Remote work", "Colour theory" ],
      titles({ from: "entries:posts", sort: "excerpt:asc" }),
      "published_at and title are columns; an order the blueprint holds was unreachable before"
    assert_equal [ "Colour theory", "Remote work", "Type scales", "Grids" ],
      titles({ from: "entries:posts", sort: "excerpt:desc" })
  end

  test "variables read from the current entry, term and declared params" do
    grids = @posts[1]
    spec = { from: "entries:posts", where: { topics: "$entry.topics" }, not: { id: "$entry.id" }, sort: "title:asc" }
    assert_equal [ "Colour theory", "Type scales" ], titles(spec, entry: grids)
    assert_equal [ "Remote work", "Type scales" ], titles({ from: "entries:posts", where: { topics: "$term" }, sort: "title:asc" }, term: @culture)
  end

  test "public queries never return drafts or trashed entries" do
    ok Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => "Draft post" }, actor: Nibble::Principal.system)
    ok Nibble::Lifecycle.call(@posts[0], :unpublish, actor: Nibble::Principal.system)

    assert_equal [ "Type scales", "Remote work", "Grids" ], titles({ from: "entries:posts" })
  end

  test "pagination reports totals and reads its page from the declared param" do
    result = run_query({ from: "entries:posts", paginate: { per_page: 3, param: "p" } }, params: { "p" => "2" })
    assert_equal [ "Colour theory" ], result.records.map(&:title)
    assert_equal({ "current_page" => 2, "per_page" => 3, "total" => 4, "last_page" => 2 }, result.pagination)
  end

  test "offset starts a paginated listing after what a featured slot already shows, so no post repeats or goes missing" do
    all = titles({ from: "entries:posts" })
    spec = { from: "entries:posts", offset: 1, paginate: { per_page: 2 } }
    first = run_query(spec, params: { "page" => "1" })
    second = run_query(spec, params: { "page" => "2" })

    assert_equal all.drop(1), first.records.map(&:title) + second.records.map(&:title)
    assert_equal({ "current_page" => 1, "per_page" => 2, "total" => 3, "last_page" => 2 }, first.pagination)
    assert_equal 3, second.pagination["total"]
  end

  test "offset past the end of a paginated listing leaves nothing and one empty page" do
    result = run_query({ from: "entries:posts", offset: 10, paginate: { per_page: 2 } })
    assert_empty result.records
    assert_equal({ "current_page" => 1, "per_page" => 2, "total" => 0, "last_page" => 1 }, result.pagination)
  end

  test "counts gives each term its published entries, none for a term without any, and tags the counted collection" do
    lonely = term("Lonely")
    result, tags = Nibble::Dependencies.track { run_query({ from: "terms:topics", counts: "posts" }) }

    assert_equal({ @design.id => 3, @culture.id => 2, lonely.id => 0 }, result.counts)
    assert_includes tags, "collection:posts"
  end

  test "counts leaves out drafts for the public and trashed entries always" do
    ok Nibble::Lifecycle.call(@posts[0], :unpublish, actor: Nibble::Principal.system)
    ok Nibble::Lifecycle.call(@posts[1], :trash, actor: Nibble::Principal.system)

    assert_equal({ @design.id => 1, @culture.id => 2 }, run_query({ from: "terms:topics", counts: "posts" }).counts)
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
      { from: "entries:posts", sort: "nope:asc" } => "sort",
      { from: "entries:posts", include: [ "excerpt" ] } => "include",
      { from: "entries:posts", fields: [ "nope" ] } => "fields",
      { from: "entries:posts", limit: 5, paginate: { per_page: 5 } } => "paginate",
      { from: "entries:posts", counts: "posts" } => "counts",
      { from: "terms:topics", counts: "nope" } => "counts",
      { from: "entries:posts", order: "x" } => "order"
    }.each do |spec, key|
      error = assert_raises(Nibble::Query::Invalid, spec.inspect) { Nibble::Query::Spec.parse(spec) }
      assert_equal key, error.key, spec.inspect
    end
  end

  test "a block's own number decides how many entries it lists" do
    set = { "id" => "a", "type" => "latest_posts", "count" => "2" }
    assert_equal 2, run_query({ from: "entries:posts", limit: "$set.count" }, set:).records.size
    paged = run_query({ from: "entries:posts", paginate: { per_page: "$set.count" } }, set:)
    assert_equal 2, paged.pagination["per_page"]
    assert_equal 2, paged.records.size
  end

  test "an editor typing a number past the cap can't make a page load more than 100 entries" do
    spec = Nibble::Query::Spec.parse({ from: "entries:posts", limit: "$set.count" }, context: Nibble::Query::Context.public(set: { "count" => 500 }))
    assert_equal 100, spec.limit
    assert_equal 1, Nibble::Query::Spec.parse({ from: "entries:posts", limit: "$set.count" }, context: Nibble::Query::Context.public(set: { "count" => -3 })).limit
  end

  # A block saved before its count field existed has it blank, and must neither vanish nor load a whole collection.
  test "a blank count takes the sidecar's default, or 100 without one, so the block still renders within the cap" do
    spec = ->(raw, set) { Nibble::Query::Spec.parse({ from: "entries:posts" }.merge(raw), context: Nibble::Query::Context.public(set:)) }
    assert_equal 3, spec.({ limit: { from: "$set.count", default: 3 } }, { "count" => "" }).limit
    assert_equal 2, spec.({ limit: { from: "$set.count", default: 3 } }, { "count" => "2" }).limit, "the editor's number wins over the default"
    assert_equal 100, spec.({ limit: "$set.count" }, { "count" => "" }).limit
    assert_equal 100, spec.({ limit: "$set.count" }, { "count" => "lots" }).limit
    assert_equal 12, spec.({ paginate: { per_page: "$set.count" } }, {}).paginate["per_page"]
    assert_equal 6, spec.({ paginate: { per_page: { from: "$set.count", default: 6 } } }, {}).paginate["per_page"]
    assert_equal 2, run_query({ from: "entries:posts", limit: { from: "$set.count", default: 2 } }, set: {}).records.size
  end

  test "a default is a number within the cap, beside a block or entry variable" do
    invalid = ->(limit) { assert_raises(Nibble::Query::Invalid) { Nibble::Query::Spec.parse({ from: "entries:posts", limit: }) }.key }
    assert_equal "limit.default", invalid.({ from: "$set.count", default: 500 })
    assert_equal "limit.default", invalid.({ from: "$set.count", default: "three" })
    assert_equal "limit", invalid.({ from: 3, default: 3 })
    assert_equal "limit", invalid.({ from: "$set.count", fallback: 3 })
  end

  test "limit variables are limited to the block or entry, and literals stay strict" do
    assert_equal "limit", assert_raises(Nibble::Query::Invalid) { Nibble::Query::Spec.parse({ from: "entries:posts", limit: "$params.n" }) }.key
    assert_equal "limit", assert_raises(Nibble::Query::Invalid) { Nibble::Query::Spec.parse({ from: "entries:posts", limit: 500 }) }.key
    assert_equal "paginate", assert_raises(Nibble::Query::Invalid) { Nibble::Query::Spec.parse({ from: "entries:posts", limit: "$set.count", paginate: { per_page: 5 } }) }.key
    assert_nothing_raised { Nibble::Query::Spec.parse({ from: "entries:posts", limit: "$entry.count", paginate: nil }) }
  end
end

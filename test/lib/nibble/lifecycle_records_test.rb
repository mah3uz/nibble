require "test_helper"

class Nibble::LifecycleRecordsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  Term = Nibble::Records::Term

  test "terms are live as soon as they're saved, with a URI from the taxonomy route" do
    term = create_term("Ruby on Rails")
    assert_equal [ "ruby-on-rails", "/tags/ruby-on-rails" ], [ term.slug, term.uri ]

    assert lifecycle(term, :save, "title" => "Rails").ok?
    assert_equal "Rails", term.reload.title
    assert_equal %w[record.created record.saved], Nibble::Records::OutboxEvent.order(:id).pluck(:name)
  end

  test "a term needs its required fields and a unique slug in its taxonomy" do
    create_term("Ruby")
    assert lifecycle(Term.new(taxonomy: "tags"), :create, "title" => "Ruby").invalid?
    assert lifecycle(Term.new(taxonomy: "tags"), :create, "title" => "").invalid?
  end

  test "trashing a term used by entries asks for confirmation first" do
    term = create_term("Ruby")
    create_entry("articles", { "tags" => [ term.id.to_s ] })

    assert lifecycle(term, :trash).needs_confirmation?
    assert lifecycle(term, :trash, "force" => true).ok?
    assert lifecycle(term.reload, :restore).ok?
  end

  test "globals are one record per set and locale, fully validated and revisioned" do
    site = Nibble::Records::GlobalSet.new(handle: "site", locale: "en")
    assert lifecycle(site, :save, "tagline" => "No name").invalid?, "site name is required"

    assert lifecycle(site, :save, "name" => "Nibble", "tagline" => "CMS").ok?
    assert lifecycle(site.reload, :save, "tagline" => "A CMS").ok?
    assert_equal({ "name" => "Nibble", "tagline" => "A CMS" }, site.reload.data.slice("name", "tagline"))
    assert_equal 2, site.revisions.count
    assert lifecycle(Nibble::Records::GlobalSet.new(handle: "nope", locale: "en"), :save, "name" => "x").invalid?
  end

  test "navigation trees accept only links the navigation allows, within its max depth" do
    doc = create_entry("docs", { "title" => "Guide" })
    article = create_entry("articles")
    nav = Nibble::Records::NavigationTree.new(handle: "docs_menu", locale: "en")

    valid = [ { "type" => "entry", "id" => doc.id, "children" => [ { "type" => "url", "title" => "Home", "url" => "/" } ] } ]
    assert lifecycle(nav, :save, "tree" => valid).ok?
    assert_equal [ [ "tree", "entry", doc.id ] ], Nibble::Records::Relation.where(source_type: "navigation").pluck(:field, :target_type, :target_id)

    assert lifecycle(nav, :save, "tree" => [ { "type" => "entry", "id" => article.id } ]).invalid?, "articles isn't allowed in this menu"
    too_deep = [ { "type" => "url", "title" => "a", "url" => "/a", "children" => [ { "type" => "url", "title" => "b", "url" => "/b",
      "children" => [ { "type" => "url", "title" => "c", "url" => "/c" } ] } ] } ]
    assert lifecycle(nav, :save, "tree" => too_deep).invalid?
    assert lifecycle(nav, :save, "tree" => [ { "type" => "entry", "id" => 0 } ]).invalid?
  end

  test "entry and term resolvers power relationship pickers and link fields" do
    doc = create_entry("docs", { "title" => "Setup guide" })
    article = create_entry("articles", { "title" => "Setup notes" })
    resolver = Nibble::Resolvers.find("entry")

    assert_equal [ doc.id.to_s ], resolver.find([ doc.id.to_s, article.id.to_s ], scope: { "collections" => [ "docs" ] }).map { |item| item["id"] }
    assert_equal [ "Setup guide", "Setup notes" ], resolver.search(query: "setup").map { |item| item["title"] }
    assert_equal({ url: doc.uri, title: "Setup guide" }, Nibble::LinkTypes.find("entry").resolver.resolve(doc.id))
    lifecycle(doc, :trash)
    assert_empty resolver.find([ doc.id.to_s ]), "trashed content can't be picked"
  end
end

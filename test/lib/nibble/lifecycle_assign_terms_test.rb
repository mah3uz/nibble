require "test_helper"

class Nibble::LifecycleAssignTermsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def live_doc(title)
    doc = create_entry("docs", { "title" => title, "body" => "Body" })
    lifecycle(doc, :submit)
    lifecycle(doc.reload, :approve)
    lifecycle(doc.reload, :publish, { "published_at" => 1.day.ago.utc.iso8601 })
    doc.reload
  end

  test "a published entry in a simple collection gets the term live, with no draft to publish" do
    tag = create_term("Pricing")
    article = publish_entry(create_entry("articles", { "title" => "Live one" }))

    result = lifecycle(article, :assign_terms, { "field" => "tags", "term_ids" => [ tag.id ] })

    assert result.ok?, result.errors.inspect
    assert_equal [ tag.id.to_s ], article.reload.data["tags"]
    assert_nil article.draft, "tagging twenty posts shouldn't mean publishing twenty posts"
  end

  test "a published entry in a review collection gets the term in its draft, so it still needs approval" do
    tag = create_term("Pricing")
    doc = live_doc("Guide")

    lifecycle(doc, :assign_terms, { "field" => "tags", "term_ids" => [ tag.id ] })

    doc.reload
    assert_nil doc.data["tags"], "review exists so published content doesn't change unapproved"
    assert_equal [ tag.id.to_s ], doc.draft.data["tags"]
  end

  test "a pending draft gets the term too, so its next publish doesn't drop it" do
    tag = create_term("Pricing")
    article = publish_entry(create_entry("articles", { "title" => "Live one" }))
    lifecycle(article, :save, { "title" => "Live one, revised" })

    lifecycle(article.reload, :assign_terms, { "field" => "tags", "term_ids" => [ tag.id ] })
    publish_entry(article.reload)

    assert_equal [ tag.id.to_s ], article.reload.data["tags"]
    assert_equal "Live one, revised", article.title
  end

  test "terms already on an entry are kept alongside the new one" do
    old = create_term("Old")
    new = create_term("New")
    article = create_entry("articles", { "title" => "Tagged", "tags" => [ old.id.to_s ] })

    lifecycle(article, :assign_terms, { "field" => "tags", "term_ids" => [ new.id ] })

    assert_equal [ old.id.to_s, new.id.to_s ], article.reload.data["tags"]
  end

  test "a field that isn't a taxonomy can't be assigned to" do
    article = create_entry("articles", { "title" => "Plain" })

    assert_not lifecycle(article, :assign_terms, { "field" => "summary", "term_ids" => [ "1" ] }).ok?
  end
end

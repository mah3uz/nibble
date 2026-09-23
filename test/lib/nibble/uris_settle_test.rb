require "test_helper"

class Nibble::UrisSettleTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def reroute_docs(route, load_defaults: "0.15.0")
    path = @nibble_themes.join("records/schema/collections/docs.yml")
    path.write(YAML.safe_load(path.read).merge("route" => route).to_yaml)
    configure_nibble_records(load_defaults:)
    Nibble.reset_schema!
  end

  def published_doc(attrs)
    entry = create_entry("docs", { "body" => "Words." }.merge(attrs))
    lifecycle(entry, :submit)
    lifecycle(entry.reload, :approve)
    publish_entry(entry.reload).reload
  end

  # A route is read when a record is saved, so without this a changed route leaves a site answering at a mix of old
  # and new addresses until every entry happens to be saved again.
  test "a changed route moves every entry, children after their parents, with a 301 from each live one" do
    parent = published_doc({ "title" => "Setup", "slug" => "setup" })
    child = published_doc({ "title" => "Keys", "slug" => "keys", "parent_id" => parent.id })
    draft = create_entry("docs", { "title" => "Soon", "slug" => "soon", "body" => "Words." })
    article = publish_entry(create_entry("articles", { "title" => "Unmoved" })).reload
    assert_equal [ "/setup", "/setup/keys" ], [ parent.uri, child.uri ]

    reroute_docs("/guides{parent_slugs}/{slug}")
    assert_equal 3, Nibble::Uris.settle!

    assert_equal [ "/guides/setup", "/guides/setup/keys", "/guides/soon" ], [ parent, child, draft ].map { |entry| entry.reload.uri }
    assert_equal({ "/setup" => "/guides/setup", "/setup/keys" => "/guides/setup/keys" },
      Nibble::Records::Redirect.where(source: "auto").to_h { |redirect| [ redirect.from, redirect.to ] },
      "a draft was never at an address anyone could link to, so it leaves no redirect")
    assert_equal article.uri, article.reload.uri
    assert_equal 0, Nibble::Uris.settle!, "a settled site has nothing left to move"
  end

  test "a site that has not raised load_defaults keeps entries where they are" do
    parent = published_doc({ "title" => "Setup", "slug" => "setup" })

    reroute_docs("/guides/{slug}", load_defaults: "0.14.7")

    assert_equal 0, Nibble::Uris.settle!
    assert_equal "/setup", parent.reload.uri
  end
end

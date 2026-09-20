require "test_helper"

class Nibble::LifecycleMoveTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def live_doc(title, **attrs)
    doc = create_entry("docs", { "title" => title, "body" => "Body" }.merge(attrs.transform_keys(&:to_s)))
    lifecycle(doc, :submit)
    lifecycle(doc.reload, :approve)
    lifecycle(doc.reload, :publish, { "published_at" => 1.day.ago.utc.iso8601 })
    doc.reload
  end

  test "moving a live entry moves it on the site, not into a draft" do
    guides = live_doc("Guides")
    setup = live_doc("Setup")

    result = lifecycle(setup, :move, { "parent_id" => guides.id, "position" => 0 })

    assert result.ok?, result.errors.inspect
    setup.reload
    assert_equal guides.id, setup.parent_id, "a tree move that waits for a republish never shows on the site"
    assert_equal "#{guides.uri}/setup", setup.uri
    assert_nil setup.draft, "a move is structure, not an edit waiting for review"
  end

  test "the old address redirects once a live entry has moved" do
    guides = live_doc("Guides")
    setup = live_doc("Setup")
    old_uri = setup.uri

    lifecycle(setup, :move, { "parent_id" => guides.id })

    assert_equal setup.reload.uri, Nibble::Records::Redirect.find_by(from: old_uri)&.to
  end

  test "publishing an older draft afterwards doesn't move the entry back" do
    guides = live_doc("Guides")
    setup = live_doc("Setup")
    lifecycle(setup, :save, { "title" => "Setup, revised" })
    assert setup.reload.draft, "precondition: an edit to a live entry waits in a draft"

    lifecycle(setup, :move, { "parent_id" => guides.id })
    lifecycle(setup.reload, :submit)
    lifecycle(setup.reload, :approve)
    lifecycle(setup.reload, :publish)

    assert_equal guides.id, setup.reload.parent_id, "the draft's stale copy of the structure would undo the move"
    assert_equal "Setup, revised", setup.title
  end

  test "an entry can't be moved under itself" do
    guides = live_doc("Guides")
    setup = live_doc("Setup", parent_id: guides.id)

    result = lifecycle(guides, :move, { "parent_id" => setup.id })

    assert_not result.ok?
    assert_nil guides.reload.parent_id
  end
end

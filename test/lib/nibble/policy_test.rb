require "test_helper"

class Nibble::PolicyTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def holding(*abilities)
    role = Nibble::Role.create!(handle: "holder_#{SecureRandom.hex(3)}", title: "Holder", abilities:)
    users(:author).tap { |user| user.roles = [ role ] }.reload
  end

  test "a write with no actor is refused outright, so no caller can forget who is acting" do
    entry = create_entry("articles")

    assert_raises(ArgumentError) { Nibble::Lifecycle.call(entry, :save, { "title" => "Anonymous" }) }
    assert_raises(ArgumentError) { Nibble::Lifecycle.call(entry, :save, { "title" => "Anonymous" }, actor: nil) }
  end

  test "Lifecycle refuses a person what their roles don't grant, whoever called it" do
    entry = create_entry("articles")
    viewer = holding("entries.articles.view")

    result = lifecycle(entry, :save, { "title" => "Changed" }, actor: viewer)

    assert result.forbidden?
    assert_equal "Article", entry.reload.title
  end

  test "approving a review needs the approve permission, not the publish one" do
    doc = create_entry("docs", { "title" => "Guide", "body" => "Body" })
    lifecycle(doc, :submit)

    assert lifecycle(doc.reload, :approve, actor: holding("entries.docs.view", "entries.docs.publish")).forbidden?,
      "publishing is a separate duty from reviewing"
    assert lifecycle(doc.reload, :approve, actor: holding("entries.docs.view", "workflow.approve.docs")).ok?
    assert_equal "approved", doc.reload.status
  end

  test "people edit their own entries with edit_own, and nobody else's" do
    author = holding("entries.articles.create", "entries.articles.edit_own")
    mine = create_entry("articles", { "title" => "Mine" }, actor: author)
    theirs = create_entry("articles", { "title" => "Theirs" })

    assert lifecycle(mine, :save, { "title" => "Mine, edited" }, actor: author).ok?
    assert lifecycle(theirs, :save, { "title" => "Taken" }, actor: author).forbidden?
  end

  test "schedule moves belong to Nibble alone, so a person can't fake one" do
    entry = create_entry("articles")
    lifecycle(entry, :publish, { "published_at" => 1.day.from_now.utc.iso8601 })

    assert lifecycle(entry.reload, :go_live, actor: users(:admin)).forbidden?
    assert lifecycle(entry.reload, :go_live).ok?
  end

  test "every lifecycle action has a permission, or is Nibble's alone" do
    system_only = %w[go_live expire]
    records = {
      "entry" => Nibble::Records::Entry.new(collection: "articles"), "term" => Nibble::Records::Term.new(taxonomy: "topics"),
      "global" => Nibble::Records::GlobalSet.new(handle: "site"), "navigation" => Nibble::Records::NavigationTree.new(handle: "main"),
      "asset" => Nibble::Records::Asset.new
    }

    Nibble::Lifecycle::HANDLERS.each do |type, handler|
      handler.constantize::ACTIONS.each do |action|
        next if system_only.include?(action)

        assert Nibble::Policy.ability(records.fetch(type), action), "#{type} #{action} would be refused to everyone but Nibble"
      end
    end
  end

  test "changes record who made them" do
    entry = create_entry("articles", {}, actor: users(:editor))
    Nibble::Events.dispatch_pending

    audit = Nibble::Records::AuditEntry.where(subject_id: entry.id).last
    assert_equal [ "user", users(:editor).id ], [ audit.actor_type, audit.actor_id ]
  end
end

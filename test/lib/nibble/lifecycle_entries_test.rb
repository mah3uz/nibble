require "test_helper"

class Nibble::LifecycleEntriesTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Entry = Nibble::Records::Entry

  test "edits to a live entry go to its draft, so the public version is untouched until publish" do
    entry = publish_entry(create_entry("articles", { "title" => "Live title", "summary" => "Live" }))

    assert lifecycle(entry, :save, "title" => "Draft title").ok?
    entry.reload
    assert_equal "Live title", entry.title, "saving must not change what visitors see"
    assert_equal "Draft title", entry.draft.data["title"]

    assert lifecycle(entry, :publish).ok?
    entry.reload
    assert_equal "Draft title", entry.title
    assert_nil entry.draft, "publishing applies and removes the draft"
  end

  test "discarding a draft leaves the live entry as it was" do
    entry = publish_entry(create_entry("articles", { "title" => "Live" }))
    lifecycle(entry, :save, "title" => "Scrapped")

    assert lifecycle(entry.reload, :discard_draft).ok?
    assert_nil entry.reload.draft
    assert_equal "Live", entry.title
  end

  test "a draft may be incomplete, but publishing requires every required field" do
    entry = create_entry("articles")
    assert lifecycle(entry, :save, "title" => "").ok?, "a half-written draft must still save"

    result = lifecycle(entry, :publish, "published_at" => 1.hour.ago.utc.iso8601)
    assert result.invalid?
    assert_includes result.errors.keys, "title"
    assert_equal "draft", entry.reload.status
  end

  test "non-required rules still apply to drafts" do
    result = lifecycle(create_entry("articles"), :save, "summary" => "far too long for the twenty character limit")
    assert result.invalid?
    assert_includes result.errors.keys, "summary"
  end

  test "a stale lock_version is a conflict, not an overwrite of someone else's save" do
    entry = create_entry("articles")
    opened = entry.lock_version
    lifecycle(entry, :save, "title" => "Colleague")

    result = lifecycle(entry.reload, :save, "title" => "Mine", "lock_version" => opened)
    assert result.conflict?
    assert_equal "Colleague", entry.reload.title
  end

  test "a guard can veto a transition with a message" do
    Nibble::Lifecycle.guard(:publish) { |record| "Legal hasn't signed off" if record.title.include?("Secret") }
    entry = create_entry("articles", { "title" => "Secret plans" })

    result = lifecycle(entry, :publish, "published_at" => 1.hour.ago.utc.iso8601)
    assert_equal({ "base" => [ "Legal hasn't signed off" ] }, result.errors)
    assert_equal "draft", entry.reload.status
  end

  test "under review, a live entry's draft is reviewed and approved before it can replace the live version" do
    doc = create_entry("docs", { "title" => "Guide" })
    doc.update_columns(status: "published", published_at: 1.day.ago)
    doc.reload

    lifecycle(doc, :save, "title" => "Guide v2")
    assert lifecycle(doc.reload, :publish).invalid?, "an unapproved draft must not go live"
    assert lifecycle(doc.reload, :submit, "comment" => "Ready").ok?
    assert_equal "published", doc.reload.status, "the live version stays public while the draft is reviewed"
    assert lifecycle(doc, :approve).ok?

    lifecycle(doc.reload, :save, "title" => "Guide v3")
    assert_nil doc.reload.draft.workflow_status, "editing an approved draft needs approval again"
    lifecycle(doc, :submit)
    lifecycle(doc.reload, :approve)
    assert lifecycle(doc.reload, :publish).ok?
    assert_equal "Guide v3", doc.reload.title
    assert_equal [ %w[draft in_review], %w[in_review approved], %w[draft in_review], %w[in_review approved] ],
      Nibble::Records::WorkflowTransition.where(record: doc).order(:id).pluck(:from, :to)
  end

  test "reverting restores old content as a new revision and never rewrites history" do
    entry = create_entry("articles", { "title" => "First" })
    first = entry.revisions.last
    lifecycle(entry, :save, "title" => "Second")

    assert lifecycle(entry.reload, :revert, "revision_id" => first.id).ok?
    assert_equal "First", entry.reload.title
    assert_equal %w[save save restore], entry.revisions.pluck(:kind)
    assert_equal({ "title" => { "from" => "First", "to" => "Second" } }, Nibble::Revisions.diff(entry, first.data, entry.revisions.second.data))
  end

  test "revisions are pruned to the collection's keep limit" do
    entry = create_entry("articles")
    5.times { |i| lifecycle(entry.reload, :save, "title" => "v#{i}") }

    assert_equal 3, entry.revisions.count
    assert_equal "v4", entry.revisions.last.data["title"]
  end

  # Publishing is asking for the entry to be live now; refusing until a date is typed in only adds a step.
  test "publishing a dated entry with no date publishes it now" do
    entry = create_entry("articles")

    freeze_time do
      assert lifecycle(entry, :publish).ok?
      assert_equal "published", entry.reload.status
      assert_equal Time.current, entry.published_at
    end
  end

  test "a future publish date schedules the entry, and the scheduler publishes it when due" do
    entry = create_entry("articles")
    assert lifecycle(entry, :publish, "published_at" => 1.hour.from_now.utc.iso8601).ok?
    assert_equal "scheduled", entry.reload.status

    Nibble::Jobs::RunSchedule.perform_now(now: 30.minutes.from_now)
    assert_equal "scheduled", entry.reload.status, "not due yet"

    travel 2.hours do
      Nibble::Jobs::RunSchedule.perform_now
    end
    assert_equal "published", entry.reload.status
  end

  test "an expiry date unpublishes the entry when due" do
    entry = publish_entry(create_entry("articles"), { "unpublish_at" => 1.hour.from_now.utc.iso8601 })

    travel 2.hours do
      Nibble::Jobs::RunSchedule.perform_now
    end
    assert_equal "unpublished", entry.reload.status
  end

  test "a live entry can't be moved to a future date, which would silently take it offline" do
    entry = publish_entry(create_entry("articles"))
    lifecycle(entry, :save, "published_at" => 1.day.from_now.utc.iso8601)

    assert lifecycle(entry.reload, :publish).invalid?
    assert_equal "published", entry.reload.status
  end

  test "URIs come from the collection route, and reserved paths are refused" do
    entry = publish_entry(create_entry("articles", { "title" => "Hello World" }), { "published_at" => "2025-03-04T10:00:00Z" })
    assert_equal "/articles/2025/hello-world", entry.uri

    blocked = lifecycle(Entry.new(collection: "docs"), :create, "title" => "CP", "body" => "x")
    assert blocked.invalid?
    assert_match "reserved", blocked.errors["uri"].first
  end

  test "moving a live entry leaves a single-hop 301 from its old URL" do
    entry = publish_entry(create_entry("articles", { "slug" => "old" }), { "published_at" => "2025-01-01T00:00:00Z" })
    Nibble::Records::Redirect.create!(from: "/elsewhere", to: "/articles/2025/old")

    lifecycle(entry, :save, "slug" => "new")
    assert_equal "/articles/2025/old", entry.reload.uri, "a draft slug change must not move the live URL"
    lifecycle(entry, :publish)

    assert_equal "/articles/2025/new", Nibble::Records::Redirect.find_by!(from: "/articles/2025/old").to
    assert_equal "/articles/2025/new", Nibble::Records::Redirect.find_by!(from: "/elsewhere").to, "chains are collapsed"
  end

  test "renaming a parent moves every descendant's URI in one job" do
    root = create_entry("docs", { "title" => "Guides" })
    child = create_entry("docs", { "title" => "Setup", "parent_id" => root.id })
    grandchild = create_entry("docs", { "title" => "Linux", "parent_id" => child.id })
    assert_equal "/guides/setup/linux", grandchild.uri

    lifecycle(root, :save, "slug" => "handbook")
    Nibble::Jobs::CascadeUris.perform_now(root.id)

    assert_equal "/handbook/setup", child.reload.uri
    assert_equal "/handbook/setup/linux", grandchild.reload.uri
    assert_equal 1, Nibble::Records::OutboxEvent.where(name: "record.uris_changed").count
  end

  test "structure rules: same collection, no cycles, max depth" do
    a = create_entry("docs", { "title" => "A" })
    b = create_entry("docs", { "title" => "B", "parent_id" => a.id })
    c = create_entry("docs", { "title" => "C", "parent_id" => b.id })

    assert lifecycle(a, :save, "parent_id" => c.id).invalid?, "an entry can't become its own descendant"
    assert lifecycle(Entry.new(collection: "docs"), :create, "title" => "D", "body" => "x", "parent_id" => c.id).invalid?, "max depth is 3"
    assert lifecycle(create_entry("articles"), :save, "parent_id" => a.id).invalid?, "articles isn't structured"
  end

  test "trashing a referenced entry asks for confirmation and lists who references it" do
    target = create_entry("articles", { "title" => "Target" })
    referrer = create_entry("articles", { "title" => "Referrer", "blocks" => [ { "type" => "quote", "source" => [ target.id.to_s ] } ] })

    result = lifecycle(target, :trash)
    assert result.needs_confirmation?
    assert_equal [ referrer ], result.referrers.map(&:source)
    assert_not target.reload.trashed?

    assert lifecycle(target, :trash, "force" => true).ok?
    assert target.reload.trashed?
  end

  test "trash frees the URI; restore reports a conflict if it was taken meanwhile and never goes straight back live" do
    entry = publish_entry(create_entry("articles", { "slug" => "taken" }), { "published_at" => "2025-01-01T00:00:00Z" })
    lifecycle(entry, :trash)
    other = publish_entry(create_entry("articles", { "slug" => "taken" }), { "published_at" => "2025-01-01T00:00:00Z" })
    assert_equal entry.uri, other.uri

    assert lifecycle(entry.reload, :restore).invalid?
    lifecycle(other, :trash)
    assert lifecycle(entry.reload, :restore).ok?
    assert_equal "unpublished", entry.reload.status
  end

  test "an entry with children can't be trashed out from under them" do
    parent = create_entry("docs", { "title" => "Parent" })
    create_entry("docs", { "title" => "Child", "parent_id" => parent.id })

    assert lifecycle(parent, :trash).invalid?
  end

  test "the purge job deletes trash older than the retention period, with its history" do
    old = create_entry("articles", { "title" => "Old" })
    recent = create_entry("articles", { "title" => "Recent" })
    lifecycle(old, :trash)
    lifecycle(recent, :trash)
    old.update_columns(deleted_at: 31.days.ago)

    Nibble::Jobs::PurgeTrash.perform_now
    assert_not Entry.exists?(old.id)
    assert_equal 0, Nibble::Records::Revision.where(record_type: "entry", record_id: old.id).count
    assert Entry.exists?(recent.id)
  end

  test "relations reflect the live content, including values nested in sets" do
    tag = create_term("Ruby")
    target = create_entry("articles", { "title" => "Target" })
    entry = create_entry("articles", { "related" => [ target.id.to_s ], "tags" => [ tag.id.to_s ],
      "blocks" => [ { "type" => "quote", "source" => [ target.id.to_s ] } ] })

    rows = Nibble::Records::Relation.where(source_type: "entry", source_id: entry.id).order(:field, :position).pluck(:field, :target_type, :target_id)
    assert_equal [ [ "blocks", "entry", target.id ], [ "related", "entry", target.id ], [ "tags", "term", tag.id ] ], rows

    publish_entry(entry)
    lifecycle(entry.reload, :save, "related" => [], "tags" => [], "blocks" => [])
    assert_equal 3, Nibble::Records::Relation.where(source_id: entry.id).count, "draft edits don't change what live content references"
  end

  test "a relationship to a missing entry is refused" do
    result = lifecycle(create_entry("articles"), :save, "related" => [ "999999" ])
    assert result.invalid?
    assert_includes result.errors.keys, "related"
  end

  test "each change is audited with its actor and field changes, and queued for async subscribers" do
    editor = users(:editor)
    Nibble::Current.set(ip: "203.0.113.9") do
      entry = create_entry("articles", { "title" => "Audited" }, actor: editor)
      lifecycle(entry, :publish, { "published_at" => 1.hour.ago.utc.iso8601 }, actor: editor)
    end

    audit = Nibble::Records::AuditEntry.where(action: "record.published").sole
    assert_equal [ "user", editor.id, "entry", "203.0.113.9" ], [ audit.actor_type, audit.actor_id, audit.subject_type, audit.ip ]
    assert audit.changeset.key?("published_at")
    assert_equal %w[record.created record.published], Nibble::Records::OutboxEvent.order(:id).pluck(:name)
    assert_raises(ActiveRecord::ReadOnlyRecord) { audit.update!(action: "tampered") }
  end
end

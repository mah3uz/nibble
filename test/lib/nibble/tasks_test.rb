require "test_helper"
require "webmock"

class Nibble::TasksTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  RATES = "https://api.example.test/rates".freeze
  FEED = "https://feed.example.test/items".freeze
  PING = "https://hooks.example.test/ping".freeze

  SCHEMA = {
    "globals/figures.yml" => { title: "Figures", blueprint: { title: "Figures", tabs: { main: { sections: [ { fields: [
      { handle: "usd", field: { type: "text" } }, { handle: "eur", field: { type: "text" } }
    ] } ] } } } },
    "collections/listings.yml" => { title: "Listings", route: "/listings/{slug}", blueprints: [ "listing" ] },
    "blueprints/collections/listings/listing.yml" => { title: "Listing", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text", required: true } }, { handle: "ref", field: { type: "text" } }
    ] } ] } } },
    "tasks/rates.yml" => { title: "Exchange rates", schedule: "every 2 hours",
                           fetch: { url: RATES, into: { global: "figures", map: { usd: "{response.rates.usd}", eur: "{response.rates.eur}" } } } },
    "tasks/feed.yml" => { title: "Listings feed", schedule: "every hour",
                          fetch: { url: FEED, into: { collection: "listings", items: "{response.data}", key: "ref", unpublish_missing: true,
                                                      map: { title: "{item.name}", ref: "{item.id}" } } } },
    "tasks/ping.yml" => { title: "Ping", schedule: "at 5am every day", request: { url: PING, body: { source: "nibble" } } },
    "tasks/custom.yml" => { title: "Custom", schedule: "every minute", handler: "test.custom" }
  }.freeze

  setup do
    SCHEMA.each do |relative, content|
      path = @nibble_themes.join("site_schema", relative)
      FileUtils.mkdir_p(path.dirname)
      path.write(content.deep_stringify_keys.to_yaml)
    end
    Nibble.reset_schema!
    WebMock.enable!
    WebMock.disable_net_connect!
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    @handlers = Nibble::Tasks.handlers.dup
  end

  teardown do
    Nibble::Tasks.handlers = @handlers
    Nibble::Outbound::Guard.resolver = @resolver
    WebMock.reset!
    WebMock.disable!
  end

  def at(text) = Time.zone.parse("2026-10-29 #{text}")
  def runs(handle) = Nibble::Records::ScheduledTaskRun.where(handle:).order(:scheduled_for)
  def figures = Nibble::Records::GlobalSet.find_by(handle: "figures", locale: "en")

  def run_now(handle)
    run = Nibble::Tasks.run_now(handle)
    perform_enqueued_jobs(only: Nibble::Jobs::RunTask)
    run.reload
  end

  def feed(*items) = stub_request(:get, FEED).to_return(status: 200, body: { data: items }.to_json)
  def listing(ref) = Nibble::Records::Entry.where(collection: "listings").find { |entry| entry.values["ref"] == ref }

  test "a slot runs once, however often the ticker or another worker reaches it" do
    Nibble::Tasks.tick(now: at("10:30"))
    assert_empty runs("rates"), "a task seen for the first time doesn't run for a slot before it existed"

    Nibble::Tasks.tick(now: at("12:00:20"))
    Nibble::Tasks.tick(now: at("12:00:50"))
    Nibble::Tasks.tick(now: at("12:01"))

    assert_equal [ at("12:00") ], runs("rates").pluck(:scheduled_for)

    other_worker = Nibble::Records::ScheduledTaskRun.create!(handle: "rates", scheduled_for: at("14:00"), status: "running")
    Nibble::Tasks.tick(now: at("14:00:30"))
    assert_equal [ at("12:00"), at("14:00") ], runs("rates").pluck(:scheduled_for)
    assert_equal "running", other_worker.reload.status
  end

  test "after downtime only the latest missed slot runs, not every one that was missed" do
    Nibble::Tasks.tick(now: at("09:30"))
    Nibble::Tasks.tick(now: at("18:30"))

    assert_equal [ at("18:00") ], runs("rates").pluck(:scheduled_for)
  end

  test "a run still going isn't overlapped, until it's old enough to have been lost" do
    Nibble::Tasks.tick(now: at("10:00:30"))
    Nibble::Tasks.tick(now: at("10:01:05"))
    Nibble::Tasks.tick(now: at("10:02:05"))

    first, second = runs("custom")
    assert_equal "queued", first.status
    assert_equal "skipped", second.status
    assert_equal "skipped", Nibble::Tasks.run_now("custom", now: at("10:30")).status

    taken_over = Nibble::Tasks.run_now("custom", now: at("11:05"))
    assert_equal "queued", taken_over.status
    assert_equal "failed", first.reload.status, "the lost run is closed, so it can't be mistaken for one still going"
    assert_nil first.started_at

    perform_enqueued_jobs(only: Nibble::Jobs::RunTask)
    assert_equal "failed", first.reload.status, "the lost run's job doesn't start once another run has taken over"
  end

  test "pausing stops a task, and resuming doesn't make up the slots it missed" do
    Nibble::Tasks.tick(now: at("09:30"))
    Nibble::Tasks.pause("rates", now: at("09:45"))
    Nibble::Tasks.tick(now: at("10:00:30"))
    Nibble::Tasks.resume("rates", now: at("11:00"))
    Nibble::Tasks.tick(now: at("11:01"))
    assert_empty runs("rates")

    Nibble::Tasks.tick(now: at("12:00:30"))
    assert_equal [ at("12:00") ], runs("rates").pluck(:scheduled_for)
  end

  test "schedules are read in the site's time zone, unless one names its own" do
    task = Nibble::Tasks.find("ping")
    assert_equal Time.utc(2026, 10, 29, 5), task.next_run_at(Time.utc(2026, 10, 29, 0)).utc

    Time.use_zone("Australia/Brisbane") do
      assert_equal Time.utc(2026, 10, 29, 19), task.next_run_at(Time.utc(2026, 10, 29, 0)).utc, "5am in Brisbane is 19:00 UTC the day before"
      Nibble::Tasks.tick(now: Time.utc(2026, 10, 29, 12))
      Nibble::Tasks.tick(now: Time.utc(2026, 10, 29, 19, 0, 30))
    end
    assert_equal [ Time.utc(2026, 10, 29, 19) ], runs("ping").pluck(:scheduled_for)
    assert_equal Time.utc(2026, 10, 29, 20), Nibble::Tasks.cron("0 5 * * * Asia/Tokyo").next_time(Time.utc(2026, 10, 29)).to_t.utc
  end

  test "fetched figures replace the stored ones, and a failing API leaves them as they were" do
    stub_request(:get, RATES).to_return(status: 200, body: { rates: { usd: "1.08", eur: "1.00" } }.to_json)
    assert_equal "succeeded", run_now("rates").status
    assert_equal({ "usd" => "1.08", "eur" => "1.00" }, figures.values.slice("usd", "eur"))

    [ { status: 503, body: "" }, { status: 200, body: "<html>maintenance</html>" } ].each do |response|
      stub_request(:get, RATES).to_return(response)
      run = run_now("rates")
      assert_equal "failed", run.status
      assert_equal({ "usd" => "1.08", "eur" => "1.00" }, figures.reload.values.slice("usd", "eur"), run.message)
    end

    Nibble::Outbound::Guard.resolver = ->(_host) { [ "10.0.0.5" ] }
    assert_equal "failed", run_now("rates").status
    assert_equal "1.08", figures.reload.values["usd"]
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }

    stub_request(:get, RATES).to_return(status: 200, body: { rates: { usd: "1.10" } }.to_json)
    run = run_now("rates")
    assert_equal "succeeded", run.status
    assert_equal({ "usd" => "1.10", "eur" => "1.00" }, figures.reload.values.slice("usd", "eur"), "a figure the response left out keeps its value")
    assert_equal [ "eur" ], run.details["missing"]
  end

  test "what an API sends back is stored as given, never read for secrets" do
    ENV["NIBBLE_SECRET_CRM_TOKEN"] = "crm-secret"
    stub_request(:get, RATES).to_return(status: 200, body: { rates: { usd: "{secret.crm_token}", eur: "x {secret.crm_token}" } }.to_json)

    assert_equal "succeeded", run_now("rates").status
    assert_equal({ "usd" => "{secret.crm_token}", "eur" => "x {secret.crm_token}" }, figures.values.slice("usd", "eur"))
  ensure
    ENV.delete("NIBBLE_SECRET_CRM_TOKEN")
  end

  test "importing the same feed twice changes nothing the second time" do
    feed({ id: "a", name: "Alpha" }, { id: "b", name: "Beta" })
    assert_equal "succeeded", run_now("feed").status
    assert_equal %w[Alpha Beta], Nibble::Records::Entry.live.where(collection: "listings").map(&:title).sort

    revisions = Nibble::Records::Revision.count
    run = run_now("feed")
    assert_equal "succeeded", run.status
    assert_equal 2, run.details["unchanged"]
    assert_equal revisions, Nibble::Records::Revision.count

    feed({ id: "a", name: "Alpha two" }, { id: "b", name: "Beta" })
    assert_equal 1, run_now("feed").details["updated"]
    assert_equal "Alpha two", listing("a").reload.title
  end

  test "an editor's unfinished work must not go live because a feed refreshed" do
    feed({ id: "a", name: "Alpha" }, { id: "b", name: "Beta" })
    run_now("feed")
    entry = listing("a")
    assert lifecycle(entry, :save, { "title" => "Alpha, being rewritten" }).ok?
    assert entry.reload.draft

    feed({ id: "a", name: "Alpha renamed" }, { id: "b", name: "Beta" })
    run = run_now("feed")
    assert_equal 1, run.details["skipped"]
    assert_equal [ "a: has unpublished edits" ], run.details["skipped_reasons"]
    assert_equal "Alpha", entry.reload.title, "the live version isn't changed under the editor"
    assert_equal "Alpha, being rewritten", entry.draft.data["title"], "the draft is left exactly as the editor left it"

    feed({ id: "b", name: "Beta" })
    run_now("feed")
    assert entry.reload.live?, "withdrawing it would fold the draft in, and bringing it back would publish it"
    assert_equal "Alpha, being rewritten", entry.draft.data["title"]

    assert lifecycle(entry, :discard_draft).ok?
    feed({ id: "a", name: "Alpha renamed" }, { id: "b", name: "Beta" })
    assert_equal 1, run_now("feed").details["updated"]
    assert_equal "Alpha renamed", entry.reload.title
  end

  test "unpublish_missing only ever unpublishes entries the task created" do
    hand_made = publish_entry(create_entry("listings", { title: "Hand made", ref: "b" }))
    keyless = publish_entry(create_entry("listings", { title: "No key" }))
    feed({ id: "a", name: "Alpha" }, { id: "b", name: "Beta" }, { name: "Nameless" })
    run = run_now("feed")
    assert_equal 2, run.details["created"]
    assert_equal 1, run.details["skipped"], "an item without a key is never imported"

    feed({ id: "a", name: "Alpha" })
    assert_equal 1, run_now("feed").details["unpublished"]
    imported_b = Nibble::Records::Entry.find_by(collection: "listings", slug: "beta")
    assert_equal "unpublished", imported_b.status
    assert hand_made.reload.live?, "a hand-made entry with the same key is not the task's"
    assert keyless.reload.live?

    feed
    run_now("feed")
    assert listing("a").reload.live?, "an empty feed is treated as a fault, not as every item withdrawn"

    feed({ id: "a", name: "Alpha" }, { id: "b", name: "Beta" })
    assert_equal 1, run_now("feed").details["republished"]
    assert imported_b.reload.live?
  end

  test "administrators hear once when a task starts failing, and again only after it has recovered" do
    stub_request(:post, PING).to_return(status: 500)
    3.times { run_now("ping") }
    notifications = Nibble::Records::Notification.where(kind: "task.failed")
    assert_equal Nibble::User.administrators.pluck(:id).sort, notifications.pluck(:user_id).sort
    assert notifications.any?

    stub_request(:post, PING).to_return(status: 204)
    assert_equal "succeeded", run_now("ping").status
    stub_request(:post, PING).to_return(status: 500)
    run_now("ping")
    assert_equal 2 * Nibble::User.administrators.count, notifications.count
  end

  test "Run now works without a ticker, and a handler can update a global and see its last success" do
    seen = []
    Nibble::Tasks.register_handler("test.custom", lambda do |context|
      seen << context.last_success_at
      context.update_global("figures", { usd: "2.00" })
      { "rows" => 1 }
    end)

    first = run_now("custom")
    second = run_now("custom")

    assert_equal [ "succeeded", "succeeded" ], [ first.status, second.status ]
    assert_equal({ "rows" => 1 }, second.details)
    assert_equal [ nil, first.started_at ], seen
    assert_equal "2.00", figures.values["usd"]
    assert first.manual
  end

  test "a request succeeds only on a 2xx answer" do
    stub_request(:post, PING).with(body: { source: "nibble" }.to_json).to_return(status: 202)
    assert_equal "succeeded", run_now("ping").status
    stub_request(:post, PING).to_return(status: 404)
    assert_match "HTTP 404", run_now("ping").message
  end

  test "runs older than thirty days are deleted as the schedule ticks" do
    old = Nibble::Records::ScheduledTaskRun.create!(handle: "rates", scheduled_for: at("01:00") - 31.days, status: "succeeded", created_at: at("01:00") - 31.days)
    recent = Nibble::Records::ScheduledTaskRun.create!(handle: "rates", scheduled_for: at("01:00") - 29.days, status: "succeeded", created_at: at("01:00") - 29.days)

    Nibble::Jobs::RunSchedule.perform_now(now: at("01:30"))

    assert_not Nibble::Records::ScheduledTaskRun.exists?(old.id)
    assert Nibble::Records::ScheduledTaskRun.exists?(recent.id)
  end
end

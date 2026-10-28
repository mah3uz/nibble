require "test_helper"

class Nibble::Cp::ScheduledTasksTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  TASKS = {
    "rates" => { title: "Exchange rates", description: "Rates for the pricing page.", schedule: "every 2 hours",
                 request: { url: "https://api.example.test/rates" } },
    "ping" => { title: "Ping", schedule: "at 5am every day", request: { url: "https://hooks.example.test/ping" } }
  }.freeze

  setup do
    TASKS.each do |handle, content|
      path = @nibble_themes.join("site_schema", "tasks", "#{handle}.yml")
      FileUtils.mkdir_p(path.dirname)
      path.write(content.deep_stringify_keys.to_yaml)
    end
    Nibble.reset_schema!
    sign_in_as users(:admin)
  end

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]
  def task(handle) = props["tasks"].find { |row| row["handle"] == handle }
  def runs(handle) = Nibble::Records::ScheduledTaskRun.where(handle:)

  test "the page shows each declared task with what an editor needs to judge it at a glance" do
    freeze_time
    Nibble::Records::ScheduledTaskRun.create!(handle: "rates", scheduled_for: 30.minutes.ago, status: "failed",
                                              started_at: 30.minutes.ago, finished_at: 29.minutes.ago, message: "the API answered HTTP 500")
    Nibble::Records::ScheduledTask.create!(handle: "rates", active_since: 1.day.ago, failing_since: 29.minutes.ago)

    get "/cp/utilities/tasks"

    assert_response :success
    assert_equal "cp/utilities/Tasks", page["component"]
    rates = task("rates")
    assert_equal [ "Exchange rates", "Rates for the pricing page.", "every 2 hours" ], rates.values_at("title", "description", "schedule")
    assert_equal Nibble::Tasks.find("rates").next_run_at.utc.iso8601, rates["next_run_at"]
    assert_equal [ "failed", "the API answered HTTP 500" ], rates["last_run"].values_at("status", "message")
    assert_equal 29.minutes.ago.utc.iso8601, rates["failing_since"], "a failing task is flagged until it succeeds again"
    assert_nil task("ping")["last_run"]
    assert_equal Time.zone.tzinfo.name, props["time_zone"], "next runs are shown in the site's clock, which tasks run on"
  end

  test "the page says when nothing starts tasks on their schedule, so a quiet list isn't mistaken for a broken one" do
    get "/cp/utilities/tasks"

    assert_equal Nibble::Cp::JobsDashboard.available?, props["scheduler"]
  end

  test "run now queues a run and says so" do
    post "/cp/utilities/tasks/rates/run"

    assert_redirected_to "/cp/utilities/tasks"
    assert_equal "queued", runs("rates").sole.status
    assert runs("rates").sole.manual
    assert_enqueued_with(job: Nibble::Jobs::RunTask, args: [ runs("rates").sole.id ])
    assert_match "queued", flash[:notice]
  end

  test "run now while the previous run is still going doesn't start a second one and says why" do
    freeze_time
    post "/cp/utilities/tasks/rates/run"
    travel 1.minute
    post "/cp/utilities/tasks/rates/run"

    assert_equal %w[queued skipped], runs("rates").order(:scheduled_for).pluck(:status)
    assert_match "still going", flash[:alert]
    assert_enqueued_jobs 1, only: Nibble::Jobs::RunTask
  end

  test "a double click on run now starts one run, and the second click is told it already started" do
    freeze_time
    post "/cp/utilities/tasks/rates/run"
    post "/cp/utilities/tasks/rates/run"

    assert_redirected_to "/cp/utilities/tasks"
    assert_equal 1, runs("rates").count
    assert_match "a moment ago", flash[:notice]
  end

  test "pausing stops scheduled runs and resuming lets them start again" do
    post "/cp/utilities/tasks/rates/pause"
    assert_redirected_to "/cp/utilities/tasks"
    get "/cp/utilities/tasks"
    assert task("rates")["paused"]
    assert_nil task("rates")["next_run_at"], "a paused task has no next run to promise"

    post "/cp/utilities/tasks/rates/resume"
    get "/cp/utilities/tasks"
    assert_not task("rates")["paused"]
    assert task("rates")["next_run_at"]
  end

  test "a task's history lists its runs with their details" do
    Nibble::Records::ScheduledTaskRun.create!(handle: "rates", scheduled_for: 1.hour.ago, status: "succeeded",
                                              message: "2 created", details: { "created" => 2, "skipped_reasons" => [ "a: has unpublished edits" ] })
    Nibble::Records::ScheduledTaskRun.create!(handle: "rates", scheduled_for: 2.hours.ago, created_at: 40.days.ago, status: "succeeded")
    Nibble::Records::ScheduledTaskRun.create!(handle: "ping", scheduled_for: 1.hour.ago, status: "failed")

    get "/cp/utilities/tasks/rates/runs", as: :json

    run = response.parsed_body["runs"].sole
    assert_equal [ "succeeded", "2 created", false ], run.values_at("status", "message", "manual")
    assert_equal [ "a: has unpublished edits" ], run["details"]["skipped_reasons"]
  end

  test "a task that isn't in the schema is not found rather than created" do
    post "/cp/utilities/tasks/nope/run"
    assert_response :not_found

    post "/cp/utilities/tasks/nope/pause"
    assert_response :not_found

    get "/cp/utilities/tasks/nope/runs", as: :json
    assert_response :not_found
    assert_empty Nibble::Records::ScheduledTask.all
    assert_empty Nibble::Records::ScheduledTaskRun.all
  end

  test "someone who can't see utilities can't make a task call out or stop it" do
    sign_in_as users(:author)

    get "/cp/utilities/tasks"
    assert_response :forbidden

    post "/cp/utilities/tasks/rates/run"
    post "/cp/utilities/tasks/ping/pause"
    get "/cp/utilities/tasks/rates/runs", as: :json

    assert_response :forbidden
    assert_empty Nibble::Records::ScheduledTaskRun.all, "no run means no outbound call"
    assert_no_enqueued_jobs only: Nibble::Jobs::RunTask
    assert_not Nibble::Records::ScheduledTask.exists?(handle: "ping", paused: true)
  end
end

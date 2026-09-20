require "test_helper"

class Nibble::HealthTest < ActiveSupport::TestCase
  BrokenStorage = Class.new { def exist?(_key) = raise(Errno::EHOSTUNREACH, "bucket unreachable") }

  teardown { SolidQueue::Record.connection.schema_cache.clear! }

  def check(name) = Nibble::Health.run.find { |item| item.name == name }

  def with_queue_tables
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/queue_schema.rb")
    SolidQueue::Record.connection.schema_cache.clear!
  end

  def worker(heartbeat: Time.current)
    SolidQueue::Process.create!(kind: "Worker", last_heartbeat_at: heartbeat, pid: 1, name: "worker-1", hostname: "test", metadata: {})
  end

  def job(queue = "deliveries") = SolidQueue::Job.create!(queue_name: queue, class_name: "Nibble::Jobs::DeliverWebhook", arguments: {})

  def with_ssr(url, enabled: true)
    config = InertiaRails.configuration
    was = [ config.ssr_enabled, config.ssr_url ]
    config.ssr_enabled = enabled
    config.ssr_url = url
    yield
  ensure
    config.ssr_enabled, config.ssr_url = was
  end

  def http_server(status)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      client = server.accept
      while (line = client.gets) && line != "\r\n"; end
      client.write("HTTP/1.1 #{status} X\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
      client.close
    end
    yield "http://127.0.0.1:#{server.addr[1]}"
  ensure
    thread&.join(1)
    server&.close
  end

  test "the database is healthy when it answers and every migration has run" do
    assert_equal "ok", check("database").status
  end

  test "a storage service that can't be reached fails the check with the reason" do
    original = ActiveStorage::Blob.service
    ActiveStorage::Blob.service = BrokenStorage.new

    storage = check("storage")

    assert_equal "fail", storage.status
    assert_match "bucket unreachable", storage.message
  ensure
    ActiveStorage::Blob.service = original
  end

  test "server rendering is healthy when its process answers, and failing when nothing does" do
    http_server(200) { |url| with_ssr(url) { assert_equal "ok", check("ssr").status } }
    http_server(500) { |url| with_ssr(url) { assert_equal [ "fail", "The SSR server answered 500" ], check("ssr").to_h.values_at(:status, :message) } }

    closed = TCPServer.new("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }
    with_ssr("http://127.0.0.1:#{closed}") { assert_match "ECONNREFUSED", check("ssr").message }
    with_ssr(nil, enabled: false) { assert_equal "skip", check("ssr").status }
  end

  test "without Solid Queue the queue check steps aside rather than failing" do
    assert_equal "skip", check("queue").status
  end

  test "no live worker means jobs won't run, so the queue check fails" do
    with_queue_tables
    worker(heartbeat: 10.minutes.ago)

    assert_equal "fail", check("queue").status
  end

  test "a stalled publishing schedule fails the check, since scheduled posts would stop going live" do
    with_queue_tables
    worker
    SolidQueue::RecurringTask.create!(key: "run_publishing_schedule", schedule: "every minute", class_name: "Nibble::Jobs::RunSchedule")
    SolidQueue::RecurringExecution.create!(job_id: job("maintenance").id, task_key: "run_publishing_schedule", run_at: 20.minutes.ago)

    assert_match "Scheduled publishing last ran", check("queue").message
  end

  test "work waiting too long or failed jobs are warnings, not outages" do
    with_queue_tables
    worker
    job.ready_execution.update_columns(created_at: 10.minutes.ago)

    assert_equal [ "warn", "Work in deliveries" ], [ check("queue").status, check("queue").message.split.first(3).join(" ") ]
  end

  test "one failing check makes the site down, a warning only degrades it" do
    ok = Nibble::Health::Check.new(name: "a", status: "ok", message: "", ms: 1)
    warn = ok.with(status: "warn")
    fail = ok.with(status: "fail")
    skip = ok.with(status: "skip")

    assert_equal "ok", Nibble::Health.status([ ok, skip ])
    assert_equal "degraded", Nibble::Health.status([ ok, warn ])
    assert_equal "down", Nibble::Health.status([ warn, fail ])
  end
end

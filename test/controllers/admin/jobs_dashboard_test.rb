require "test_helper"

class Admin::JobsDashboardTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def jobs = page["props"]["jobs"]

  def with_queue_tables
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/queue_schema.rb")
    SolidQueue::Record.connection.schema_cache.clear!
  end

  def enqueue(klass, queue)
    SolidQueue::Job.create!(queue_name: queue, class_name: klass, arguments: { "job_class" => klass, "arguments" => [] })
  end

  def fail(job, message = "the endpoint refused")
    job.ready_execution&.destroy!
    error = RuntimeError.new(message).tap { |exception| exception.set_backtrace([ "app/jobs/example.rb:1", "lib/other.rb:2" ]) }
    job.failed_with(error)
    SolidQueue::FailedExecution.find_by!(job_id: job.id)
  end

  setup { sign_in_as users(:admin) }
  teardown { SolidQueue::Record.connection.schema_cache.clear! }

  test "without a Solid Queue the screen says jobs run in-process instead of pretending the queue is empty" do
    get "/admin/utilities/jobs"

    assert_response :success
    assert_equal({ "available" => false }, jobs)
  end

  test "every queue the engine uses is listed, with what's waiting in it" do
    with_queue_tables
    2.times { enqueue("Nibble::Jobs::DeliverWebhook", "deliveries") }

    get "/admin/utilities/jobs"

    queues = jobs["queues"].to_h { |queue| [ queue["name"], queue["ready"] ] }
    assert_equal %w[events deliveries media search maintenance], queues.keys
    assert_equal 2, queues["deliveries"]
    assert_equal 0, queues["media"]
  end

  test "a failed job shows its error and where it came from" do
    with_queue_tables
    fail(enqueue("Nibble::Jobs::DeliverWebhook", "deliveries"))

    get "/admin/utilities/jobs"

    failure = jobs["failed"].sole
    assert_equal [ "Nibble::Jobs::DeliverWebhook", "RuntimeError", "the endpoint refused" ], failure.values_at("job", "exception", "message")
    assert_equal [ "app/jobs/example.rb:1", "lib/other.rb:2" ], failure["backtrace"]
  end

  test "retrying puts a failed job back in its queue" do
    with_queue_tables
    job = enqueue("Nibble::Jobs::DeliverWebhook", "deliveries")
    failure = fail(job)

    post "/admin/utilities/jobs/#{failure.id}/retry"

    assert_not SolidQueue::FailedExecution.exists?(failure.id)
    assert SolidQueue::ReadyExecution.exists?(job_id: job.id), "it's waiting to run again"
  end

  test "discarding removes a failed job for good" do
    with_queue_tables
    job = enqueue("Nibble::Jobs::DeliverWebhook", "deliveries")
    failure = fail(job)

    delete "/admin/utilities/jobs/#{failure.id}"

    assert_not SolidQueue::Job.exists?(job.id)
  end

  test "a job that really failed runs to the end once its cause is fixed and it is retried from the screen" do
    with_queue_tables
    worker = SolidQueue::Process.register(kind: "Worker", pid: ::Process.pid, hostname: "test", name: "worker-gate", metadata: {})
    work = lambda do
      SolidQueue::ReadyExecution.claim("media", 1, worker.id).sole.perform
    rescue StandardError
      nil
    end
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    asset = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, {}).record
    blob.update!(metadata: {})
    asset.update_columns(width: nil, height: nil)
    ActiveStorage::Blob.service.delete(blob.key)
    adapter = Nibble::Jobs::AnalyzeAsset.queue_adapter
    Nibble::Jobs::AnalyzeAsset.queue_adapter = ActiveJob::QueueAdapters::SolidQueueAdapter.new
    Nibble::Jobs::AnalyzeAsset.perform_later(asset)
    job = SolidQueue::Job.last

    work.call

    get "/admin/utilities/jobs"
    failure = jobs["failed"].sole
    assert_equal [ "Nibble::Jobs::AnalyzeAsset", "ActiveStorage::FileNotFoundError" ], failure.values_at("job", "exception")

    ActiveStorage::Blob.service.upload(blob.key, file_fixture("photo.jpg").open)
    post "/admin/utilities/jobs/#{failure['id']}/retry"
    work.call

    assert job.reload.finished_at?, "the retried job ran to the end"
    assert_empty SolidQueue::FailedExecution.all
    assert asset.reload.width.to_i.positive?, "the job did its work the second time"
  ensure
    Nibble::Jobs::AnalyzeAsset.queue_adapter = adapter if adapter
  end

  test "people who can't see utilities can't see or touch jobs" do
    with_queue_tables
    failure = fail(enqueue("Nibble::Jobs::DeliverWebhook", "deliveries"))
    sign_in_as users(:author)

    get "/admin/utilities/jobs"
    assert_response :forbidden

    post "/admin/utilities/jobs/#{failure.id}/retry"
    assert SolidQueue::FailedExecution.exists?(failure.id)
  end
end

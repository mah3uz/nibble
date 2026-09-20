require "test_helper"

class Nibble::EventsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    Nibble::Events.reset!
    @delivered = Concurrent::Array.new
    Nibble::Events.subscribe("record.*", async: true) { |name, payload| @delivered << [ name, payload["id"] ] }
  end

  teardown do
    Nibble::Records::OutboxEvent.delete_all
    Nibble.boot!
  end

  test "an event published in a rolled-back transaction is never delivered" do
    ActiveRecord::Base.transaction do
      Nibble::Events.publish("record.saved", id: 1)
      raise ActiveRecord::Rollback
    end

    Nibble::Events.dispatch_pending
    assert_empty @delivered, "subscribers must never see a change that didn't commit"
    assert_equal 0, Nibble::Records::OutboxEvent.count
  end

  test "a synchronous subscriber failure rolls back the change together with its event" do
    Nibble::Events.subscribe("record.saved") { raise "derived data couldn't be written" }

    assert_raises(RuntimeError) do
      ActiveRecord::Base.transaction { Nibble::Events.publish("record.saved", id: 1) }
    end
    assert_equal 0, Nibble::Records::OutboxEvent.count
  end

  test "an event committed but not yet dispatched (a crash in between) is delivered by the next dispatch" do
    Nibble::Records::OutboxEvent.create!(name: "record.published", payload: { "id" => 7 })

    assert_equal 1, Nibble::Events.dispatch_pending
    assert_equal [ [ "record.published", 7 ] ], @delivered.to_a
  end

  test "a subscriber that fails leaves the event pending, so it's retried rather than lost" do
    attempts = 0
    Nibble::Events.subscribe("record.saved", async: true) { attempts += 1; raise "webhook down" if attempts == 1 }
    Nibble::Records::OutboxEvent.create!(name: "record.saved", payload: { "id" => 3 })

    assert_raises(RuntimeError) { Nibble::Events.dispatch_pending }
    assert_equal 1, Nibble::Records::OutboxEvent.pending.count

    Nibble::Events.dispatch_pending
    assert_equal 0, Nibble::Records::OutboxEvent.pending.count
  end

  test "concurrent dispatchers deliver each event exactly once" do
    Nibble::Events.subscribe("record.saved", async: true) { sleep 0.01 }
    5.times { |id| Nibble::Records::OutboxEvent.create!(name: "record.saved", payload: { "id" => id }) }

    4.times.map { Thread.new { ActiveRecord::Base.connection_pool.with_connection { Nibble::Events.dispatch_pending } } }.each(&:join)

    assert_equal [ 0, 1, 2, 3, 4 ], @delivered.map(&:last).sort
  end

  test "publishing delivers nothing until the dispatcher runs after commit" do
    Nibble::Events.publish("record.created", id: 9)
    assert_empty @delivered

    Nibble::Events.dispatch_pending
    assert_equal [ [ "record.created", 9 ] ], @delivered.to_a
  end
end

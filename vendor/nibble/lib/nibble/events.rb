module Nibble
  module Events
    Subscriber = Data.define(:pattern, :handler, :async) do
      def matches?(name) = pattern.end_with?(".*") ? name.start_with?(pattern.delete_suffix("*")) : pattern == name
    end

    class << self
      def subscribe(pattern, handler = nil, async: false, &block)
        subscribers << Subscriber.new(pattern: pattern.to_s, handler: handler || block, async:)
      end

      def reset! = @subscribers = []

      def publish(name, payload)
        name = name.to_s
        payload = payload.deep_stringify_keys
        Records::OutboxEvent.transaction do
          matching(name, async: false).each { |subscriber| subscriber.handler.call(name, payload) }
          Records::OutboxEvent.create!(name:, payload:)
        end
        schedule_dispatch
      end

      # One dispatcher per commit: a job per event would have them queue up behind each other for the write lock.
      def schedule_dispatch
        return if Thread.current[:nibble_dispatch_scheduled]

        Thread.current[:nibble_dispatch_scheduled] = true
        ActiveRecord.after_all_transactions_commit do
          Thread.current[:nibble_dispatch_scheduled] = false
          Jobs::DispatchEvents.perform_later
        end
      end

      def dispatch_pending(limit: 100)
        Records::OutboxEvent.pending.order(:id).limit(limit).pluck(:id).count { |id| dispatch(id) }
      end

      private

      def subscribers = @subscribers ||= []
      def matching(name, async:) = subscribers.select { |subscriber| subscriber.async == async && subscriber.matches?(name) }

      # Claiming and delivering share one transaction: a crash rolls the claim back, and a concurrent claim finds nothing.
      def dispatch(id)
        Records::OutboxEvent.transaction do
          claimed = Records::OutboxEvent.pending.where(id:).update_all(dispatched_at: Time.current)
          next false unless claimed == 1

          event = Records::OutboxEvent.find(id)
          payload = event.payload.merge("outbox_id" => event.id)
          matching(event.name, async: true).each { |subscriber| subscriber.handler.call(event.name, payload) }
          true
        end
      end
    end
  end
end

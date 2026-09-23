module Nibble
  class Lifecycle
    Result = Data.define(:status, :record, :errors, :referrers) do
      def ok? = status == :ok
      def invalid? = status == :invalid
      def conflict? = status == :conflict
      def needs_confirmation? = status == :confirm
    end

    class Invalid < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors.transform_values { |messages| Array(messages) }
        super(@errors.values.flatten.first)
      end
    end

    class NeedsConfirmation < StandardError
      attr_reader :referrers

      def initialize(referrers)
        @referrers = referrers
        super("the record is referenced by other content")
      end
    end

    HANDLERS = {
      "entry" => "Nibble::Lifecycle::Entries",
      "term" => "Nibble::Lifecycle::Terms",
      "global" => "Nibble::Lifecycle::Globals",
      "navigation" => "Nibble::Lifecycle::Navigation",
      "asset" => "Nibble::Lifecycle::Assets"
    }.freeze

    class << self
      def call(record, action, attrs = {}, actor: nil, mode: nil)
        action = action.to_s
        attrs = attrs.to_h.deep_stringify_keys
        handler_class = HANDLERS.fetch(record.record_type).constantize
        raise Error, "#{record.record_type} has no '#{action}' action" unless handler_class::ACTIONS.include?(action)

        if record.trashed? && action != "restore"
          return result(:invalid, record, errors: { "base" => [ "This is in the trash; restore it first." ] })
        end
        if (veto = guards[action].lazy.filter_map { |guard| guard.call(record, attrs, actor) }.first)
          return result(:invalid, record, errors: { "base" => [ veto ] })
        end
        if attrs.key?("lock_version") && attrs["lock_version"].to_i != record.lock_version
          return result(:conflict, record, errors: { "lock_version" => [ "Someone saved this after you opened it." ] })
        end

        record.class.transaction { handler_class.new(record, attrs, actor:, mode:, action:).public_send(action) }
        result(:ok, record)
      rescue Invalid => error
        result(:invalid, record, errors: error.errors)
      rescue ActiveRecord::RecordInvalid => error
        result(:invalid, record, errors: error.record.errors.to_hash(true).transform_keys(&:to_s))
      rescue NeedsConfirmation => error
        result(:confirm, record, referrers: error.referrers)
      rescue ActiveRecord::StaleObjectError
        result(:conflict, record, errors: { "lock_version" => [ "Someone saved this after you opened it." ] })
      end

      def guard(action, callable = nil, &block) = guards[action.to_s] << (callable || block)
      def reset_guards! = @guards = nil

      private

      def guards = @guards ||= Hash.new { |hash, key| hash[key] = [] }

      def result(status, record, errors: {}, referrers: []) = Result.new(status:, record:, errors:, referrers:)
    end
  end
end

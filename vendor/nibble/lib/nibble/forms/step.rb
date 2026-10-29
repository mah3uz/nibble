module Nibble
  module Forms
    class Step < Submit
      CHECKS_PER_REQUEST = 20

      def self.call(form, params, index:, **options) = new(form, params, index:, **options).call

      def initialize(form, params, index:, **options)
        super(form, params, **options)
        @index = index
      end

      def process
        return closed if @form.closed?

        fields = @form.fields
        values = @params.slice(*fields.handles).merge(hidden_values(fields))
        handles = @form.sections[@index]["fields"].handles
        errors = errors_in(fields, values).select { |key, _| handles.include?(key.to_s.split(".").first) }
        errors.any? ? result(:invalid, errors:) : result(:ok)
      end

      private

      def rate_limited
        return unless rate_limit_store.call.read(rate_key("step")).to_i >= @form.rate_limit["requests"] * CHECKS_PER_REQUEST

        window_end - Time.current.to_i
      end

      def count(_kind) = super("step")
    end
  end
end

module Nibble
  module Fieldtypes
    CORE = %w[
      Nibble::Fieldtypes::Text Nibble::Fieldtypes::Textarea Nibble::Fieldtypes::Integer Nibble::Fieldtypes::Toggle
      Nibble::Fieldtypes::Select Nibble::Fieldtypes::Radio Nibble::Fieldtypes::Checkboxes Nibble::Fieldtypes::Date
      Nibble::Fieldtypes::Slug Nibble::Fieldtypes::RichText Nibble::Fieldtypes::Link Nibble::Fieldtypes::List Nibble::Fieldtypes::Seo
      Nibble::Fieldtypes::Grid Nibble::Fieldtypes::Replicator Nibble::Fieldtypes::Assets Nibble::Fieldtypes::Entries Nibble::Fieldtypes::Terms
      Nibble::Fieldtypes::Secret Nibble::Fieldtypes::Files
    ].freeze

    class << self
      def register(klass_or_name)
        name = klass_or_name.is_a?(String) ? klass_or_name : klass_or_name.name
        registered[name.constantize.handle] = name
      end

      def unregister(handle) = registered.delete(handle.to_s)

      def find(handle)
        name = registered[handle.to_s] or raise Error, "unknown fieldtype '#{handle}' (registered: #{handles.join(', ')})"
        name.constantize
      end

      def exists?(handle) = registered.key?(handle.to_s)

      def handles = registered.keys.sort

      def all = handles.map { |handle| find(handle) }

      private

      def registered
        @registered ||= CORE.to_h { |name| [ name.constantize.handle, name ] }
      end
    end
  end
end

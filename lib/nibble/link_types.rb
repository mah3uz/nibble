module Nibble
  # Typed link values ("entry::<id>") are resolved by the record layer that registers each type.
  module LinkTypes
    SEPARATOR = "::".freeze

    Type = Data.define(:handle, :title, :resolver)

    class << self
      def register(handle, title:, resolver:)
        types[handle.to_s] = Type.new(handle: handle.to_s, title:, resolver:)
      end

      def unregister(handle) = types.delete(handle.to_s)
      def all = types.values
      def find(handle)
        type = types[handle.to_s]
        override = type && Resolvers.override(handle)
        override ? type.with(resolver: override) : type
      end

      def parse(value)
        return nil unless value.is_a?(String)

        handle, id = value.split(SEPARATOR, 2)
        id && find(handle) ? [ handle, id ] : nil
      end

      private

      def types = @types ||= {}
    end
  end
end

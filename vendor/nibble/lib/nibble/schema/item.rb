module Nibble
  class Schema
    Item = Data.define(:kind, :handle, :parent, :path, :layer, :data) do
      def key = [ kind, parent, handle ].compact.join("/")

      def [](name) = data[name.to_s]
    end
  end
end

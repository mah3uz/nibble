module Nibble
  module Packages
    class Keys
      def initialize
        @entries = Records::Entry.kept.pluck(:id, :collection, :slug, :parent_id).to_h { |id, *rest| [ id, rest ] }
        @terms = Records::Term.kept.pluck(:id, :taxonomy, :slug).to_h { |id, *rest| [ id, rest ] }
        @assets = Records::Asset.kept.pluck(:id, :folder, :filename).to_h { |id, *rest| [ id, rest ] }
      end

      def key(type, id)
        case type.to_s
        when "entry" then entry_key(id)
        when "term" then term_key(id)
        when "asset" then asset_key(id)
        end
      end

      def entry_key(id)
        row = @entries[id.to_i] or return nil

        collection, slug, parent_id = row
        slugs = [ slug ]
        while parent_id
          parent = @entries[parent_id] or break
          slugs.unshift(parent[1])
          parent_id = parent[2]
        end
        [ collection, *slugs ].join("/")
      end

      def term_key(id)
        row = @terms[id.to_i] or return nil

        row.join("/")
      end

      def asset_key(id)
        row = @assets[id.to_i] or return nil

        [ row.first.presence, row.last ].compact.join("/")
      end
    end

    class ExportContext
      def initialize(keys) = @keys = keys

      def resolve(type, id) = @keys.key(type, id)
    end
  end
end

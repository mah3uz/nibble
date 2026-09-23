module Nibble
  module Testing
    # Include in a Minitest case and call `assert_fieldtype_contract(Klass)` for every fieldtype, core or extension.
    module FieldtypeContract
      def assert_fieldtype_contract(klass)
        handle = klass.handle
        fieldtype = Field.new(handle, { "type" => handle }).fieldtype

        assert klass.config_fields, "#{handle}: config fields must load"
        assert_includes Fieldtype::CATEGORIES, klass.categories.first, "#{handle}: first category must be a known category" if klass.categories.any?
        assert_not_equal "unknown", fieldtype.ts_type, "#{handle}: must declare a TypeScript type for generated theme types"

        default = fieldtype.pre_process(fieldtype.default_value)
        survives(handle, "a default value must survive process") { fieldtype.process(default) }
        survives(handle, "augmenting an empty value must be safe") { fieldtype.augment(nil) }

        klass.contract_samples.each do |raw|
          assert_same_value raw, fieldtype.process(fieldtype.pre_process(raw)), "#{handle}: editing then saving #{raw.inspect} must not change it"
          assert_same_value raw, fieldtype.import(fieldtype.export(raw)), "#{handle}: export then import #{raw.inspect} must not change it"

          relations = fieldtype.relations(raw)
          assert_kind_of Array, relations, "#{handle}: relations must be a list"
          relations.each { |pair| assert_equal 2, Array(pair).size, "#{handle}: each relation is [type, id]" }
          assert_kind_of Array, fieldtype.dependencies(raw), "#{handle}: dependencies must be a list of cache tags"
        end
      end

      private

      def assert_same_value(expected, actual, message)
        expected.nil? ? assert_nil(actual, message) : assert_equal(expected, actual, message)
      end

      def survives(handle, expectation)
        yield
      rescue StandardError => e
        flunk "#{handle}: #{expectation} (#{e.class}: #{e.message})"
      end
    end
  end
end

require "test_helper"

class Nibble::OperationsCatalogueTest < ActiveSupport::TestCase
  SNAPSHOT = Rails.root.join("test/fixtures/files/operations_catalogue.json")

  def surface
    Nibble::Operations.all.sort_by(&:name).to_h do |operation|
      [ operation.name, { "arguments" => operation.input["properties"].keys.sort, "required" => Array(operation.input["required"]).sort,
                          "annotations" => operation.annotations } ]
    end
  end

  # Apps and scripts are built against these names; regenerate with NIBBLE_UPDATE_CATALOGUE=1 once a change is intended.
  test "the operations apps can call change only on purpose" do
    SNAPSHOT.write("#{JSON.pretty_generate(surface)}\n") if ENV["NIBBLE_UPDATE_CATALOGUE"]
    recorded = JSON.parse(SNAPSHOT.read)

    removed = recorded.keys - surface.keys
    assert_empty removed, "removing an operation breaks every app that calls it"
    recorded.each do |name, entry|
      next unless surface[name]

      assert_empty entry["arguments"] - surface[name]["arguments"], "#{name} lost an argument apps may send"
      assert_empty surface[name]["required"] - entry["required"], "#{name} now requires something older apps don't send"
    end
    assert_equal recorded, surface, "the catalogue changed; review it and regenerate the snapshot"
  end
end

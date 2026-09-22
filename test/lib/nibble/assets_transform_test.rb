require "test_helper"

class Nibble::AssetsTransformTest < ActiveSupport::TestCase
  Transform = Nibble::Assets::Transform

  def stub_probe(implementation)
    original = Transform.method(:probe_encodable)
    Transform.define_singleton_method(:probe_encodable, &implementation)
    Transform.instance_variable_set(:@encodable, nil)
    @restore_probe = -> {
      Transform.define_singleton_method(:probe_encodable, original)
      Transform.instance_variable_set(:@encodable, nil)
    }
  end

  teardown { @restore_probe&.call }

  test "a format is only offered once it has actually been encoded, not merely read" do
    stub_probe(->(_format) { false })

    assert_not Transform.encodable?("avif")
  end

  test "the probe runs once per format and its answer is remembered for the process" do
    calls = 0
    stub_probe(->(_format) { calls += 1; true })

    3.times { Transform.encodable?("avif") }
    Transform.encodable?("webp")

    assert_equal 2, calls, "avif is probed once, webp once, not once per request"
  end

  test "a browser is offered a format only when the server can actually write it" do
    stub_probe(->(format) { format != "avif" })

    assert_equal "webp", Transform.format_for(build_asset, "image/avif,image/webp,*/*"),
      "avif is skipped rather than sent to a saver that would 500 on it"
    assert_equal "webp", Transform.format_for(build_asset, "image/webp,*/*")
  end

  test "nothing offered falls back to the asset's own kind, exactly as before" do
    stub_probe(->(_format) { false })

    assert_equal "png", Transform.format_for(build_asset(extension: "png"), "image/avif,image/webp,*/*")
    assert_equal "jpg", Transform.format_for(build_asset(extension: "jpg"), "image/avif,image/webp,*/*")
  end

  private

  def build_asset(extension: "jpg") = Nibble::Records::Asset.new(filename: "photo.#{extension}")
end

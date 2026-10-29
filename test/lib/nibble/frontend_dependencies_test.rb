require "test_helper"

# A site installs Nibble's frontend from vendor/nibble/package.json. A package that is only there because another one
# depends on it is hoisted in this repo and in some installs, so the build passes here and fails on a site.
class FrontendDependenciesTest < ActiveSupport::TestCase
  ROOT = Nibble.core_root
  ALIASES = %w[@nibble @nibble-cp @theme @site @/ ~/ virtual: node:].freeze
  IMPORT = /(?:\bfrom\s+|\bimport\s*\(\s*|^\s*import\s+)["']([^"'.][^"']*)["']/

  def declared(path)
    json = JSON.parse(path.read)
    %w[dependencies devDependencies peerDependencies].flat_map { |key| json.fetch(key, {}).keys }
  end

  def package_name(spec) = spec.start_with?("@") ? spec.split("/").first(2).join("/") : spec.split("/").first

  def imports(dir)
    dir.glob("**/*.{ts,vue,js,mjs}").reject { |file| file.to_s.include?("__tests__") || file.basename.to_s.end_with?(".config.ts") }
      .flat_map { |file| file.read.scan(IMPORT).flatten.map { |spec| [ package_name(spec), file.relative_path_from(ROOT).to_s ] } }
      .reject { |name, _| ALIASES.any? { |prefix| name.start_with?(prefix) } || name == "@" }
  end

  test "every package Nibble's frontend imports is declared in its package.json" do
    known = declared(ROOT.join("package.json"))
    missing = imports(ROOT.join("frontend")).reject { |name, _| known.include?(name) }

    assert_empty missing.uniq(&:first).map { |name, file| "#{name} (#{file})" }
  end

  test "every package a shipped theme imports is declared by Nibble or the theme" do
    nibble = declared(ROOT.join("package.json"))
    missing = ROOT.join("themes").children.select(&:directory?).flat_map do |theme|
      own = theme.join("package.json").file? ? declared(theme.join("package.json")) : []
      imports(theme).reject { |name, _| nibble.include?(name) || own.include?(name) }
    end

    assert_empty missing.uniq(&:first).map { |name, file| "#{name} (#{file})" }
  end
end

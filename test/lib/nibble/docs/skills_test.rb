require "test_helper"

class BundledSkillsTest < ActiveSupport::TestCase
  DOCS = Nibble.core_root.join("docs")
  SKILLS = Nibble.core_root.join("skills").glob("*/SKILL.md")

  # An agent reads a skill instead of the docs; a guide it names that has moved sends it nowhere.
  test "every docs page a bundled skill names exists" do
    missing = SKILLS.flat_map do |skill|
      skill.read.scan(%r{`([a-z-]+/[a-z0-9-]+\.md)`}).flatten.reject { |page| DOCS.join(page).file? }.map { |page| "#{skill.parent.basename}: #{page}" }
    end

    assert_empty missing
  end

  test "the schema skill lists every fieldtype" do
    text = Nibble.core_root.join("skills/nibble-schema/SKILL.md").read
    missing = Nibble::Fieldtypes.handles.reject { |handle| text.include?("`#{handle}`") }

    assert_empty missing, "add these to the Fieldtypes list in skills/nibble-schema/SKILL.md"
  end
end

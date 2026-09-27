require "test_helper"

class Nibble::AgentGuideTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  test "the skill file names itself after the site and says when to use it" do
    skill = Nibble::AgentGuide.skill(site: "Field Notes", url: "https://notes.example")
    front = YAML.safe_load(skill[/\A---\n(.*?)\n---/m, 1])

    assert_equal "nibble-field-notes", front["name"]
    assert_match "https://notes.example", front["description"]
    assert_match "**Articles** (`articles`)", skill, "the content model comes from the schema"
  end

  test "the fingerprint moves when the site's notes change, so an installed skill knows it's stale" do
    before = Nibble::AgentGuide.document(site: "S", url: "https://s.example")["fingerprint"]
    FileUtils.mkdir_p(Nibble.config.agents_path)
    Nibble.config.agents_path.join("style.md").write("Use sentence case in headings.")

    assert_not_equal before, Nibble::AgentGuide.document(site: "S", url: "https://s.example")["fingerprint"]
  end
end

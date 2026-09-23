require "test_helper"

class NibbleHelpTest < ActiveSupport::TestCase
  def help = capture_io { Rails::Command.invoke("nibble:help") }.first

  test "the help opens with the release and what it runs on, so a bug report can start from it" do
    assert_match(/\A╭─ Nibble #{Regexp.escape(Nibble::VERSION)} ─+╮\n/, help)
    assert_includes help, "Ruby #{RUBY_VERSION} · Rails #{Rails.version}"
    assert_includes help, "theme API #{Nibble::THEME_API_VERSION} · schema format #{Nibble::SCHEMA_FORMAT}"
  end

  test "every command a site can run is listed, including the grouped ones Thor's own list leaves out" do
    assert_includes help, "bin/rails nibble:upgrade [VERSION]"
    assert_includes help, "bin/rails nibble:admin:create"
    assert_includes help, "bin/rails nibble:schema:types"
  end

  test "commands only Nibble calls, and Thor's generic ones, are left out" do
    assert_not_includes help, "nibble:upgrade:finish"
    assert_not_includes help, "nibble:help [COMMAND]"
    assert_not_includes help, ":tree"
  end
end

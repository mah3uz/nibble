require "test_helper"

class Nibble::PackagesArchiveTest < ActiveSupport::TestCase
  Archive = Nibble::Packages::Archive

  setup { @into = Pathname(Dir.mktmpdir("nibble-archive")) }
  teardown { FileUtils.rm_rf(@into) }

  def zip(files, symlinks = {})
    buffer = Zip::OutputStream.write_buffer do |out|
      files.each do |name, content|
        out.put_next_entry(name)
        out.write(content)
      end
      symlinks.each do |name, target|
        entry = Zip::Entry.new("", name)
        entry.instance_variable_set(:@ftype, :symlink)
        entry.fstype = Zip::FSTYPE_UNIX
        entry.unix_perms = 0o777
        out.put_next_entry(entry)
        out.write(target)
      end
    end
    StringIO.new(buffer.string)
  end

  def extracted = Dir.glob("**/*", base: @into).select { |path| @into.join(path).file? }.sort

  test "a package survives being zipped and unzipped unchanged" do
    source = Pathname(Dir.mktmpdir("nibble-source"))
    source.join("collections/posts/en").mkpath
    source.join("collections/posts/en/hello.yml").write("title: Hello\n")
    source.join("redirects.yml").write("[]\n")

    Archive.extract(StringIO.new(Archive.write(source)), into: @into)

    assert_equal %w[collections/posts/en/hello.yml redirects.yml], extracted
    assert_equal "title: Hello\n", @into.join("collections/posts/en/hello.yml").read
  ensure
    FileUtils.rm_rf(source)
  end

  test "a zipped folder unpacks as the package inside it, since that's what compressing a folder makes" do
    Archive.extract(zip("my-site/collections/posts/en/a.yml" => "title: A\n", "my-site/redirects.yml" => "[]\n"), into: @into)

    assert_equal %w[collections/posts/en/a.yml redirects.yml], extracted
  end

  test "only package files come out; anything else in the zip is ignored" do
    Archive.extract(zip("collections/posts/en/a.yml" => "x", "notes.txt" => "x", ".DS_Store" => "x",
                        "__MACOSX/collections/._a.yml" => "x", "run.rb" => "x"), into: @into)

    assert_equal %w[collections/posts/en/a.yml], extracted
  end

  test "an entry that climbs out of the package is refused before anything is written" do
    parent = @into.join("..", "escaped.yml").expand_path

    error = assert_raises(Nibble::Error) { Archive.extract(zip("collections/a.yml" => "x", "../escaped.yml" => "x"), into: @into) }

    assert_match "points outside the package", error.message
    assert_not parent.exist?
    assert_empty extracted, "the safe entry beside it wasn't written either"
  end

  test "absolute paths are refused, whichever system they come from" do
    hostile = StringIO.new(zip("_etc/cron.d/x.yml" => "x").string.gsub("_etc/cron.d", "/etc/cron.d"))

    assert_raises(Nibble::Error) { Archive.extract(hostile, into: @into) }
    assert_raises(Nibble::Error) { Archive.extract(zip("C:/Windows/x.yml" => "x"), into: @into) }
    assert_empty extracted
  end

  test "Windows-style separators land in the right place" do
    Archive.extract(zip("collections\\posts\\en\\a.yml" => "title: A\n"), into: @into)

    assert_equal %w[collections/posts/en/a.yml], extracted
  end

  test "a symlink is refused, because following it could read files outside the package" do
    error = assert_raises(Nibble::Error) do
      Archive.extract(zip({ "collections/posts/en/a.yml" => "x" }, { "collections/posts/en/b.yml" => "/etc/passwd" }), into: @into)
    end

    assert_match "is a link", error.message
  end

  test "a zip that would unpack too large or into too many files is refused up front" do
    big = zip("collections/a.yml" => "x" * 2_000, "collections/b.yml" => "y")

    assert_match "more than", assert_raises(Nibble::Error) { Archive.extract(big, into: @into, max_bytes: 1_000) }.message
    assert_match "more than 1 files", assert_raises(Nibble::Error) { Archive.extract(zip("a.yml" => "x", "b.yml" => "y"), into: @into, max_files: 1) }.message
  end

  test "something that isn't a zip gets a plain message, not a crash" do
    error = assert_raises(Nibble::Error) { Archive.extract(StringIO.new("definitely not a zip"), into: @into) }

    assert_match "isn't a readable zip file", error.message
  end
end

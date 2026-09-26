require "test_helper"

class Nibble::EjectTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir("nibble-eject"))
    @source = "vendor/nibble/frontend/nibble-cp/pages/cp/Dashboard.vue"
    write(@source, "<template>ours</template>")
  end

  teardown { FileUtils.rm_rf(@root) }

  # vendor/nibble as a release leaves it: these files, and a MANIFEST of what they were.
  def release(files)
    files.each { |relative, body| write(relative, body) }
    manifest = files.keys.map { |relative| "#{Digest::SHA256.hexdigest(files[relative])}  #{relative.delete_prefix('vendor/nibble/')}\n" }
    write("vendor/nibble/MANIFEST", manifest.sort.join)
  end

  def write(relative, body)
    path = @root.join(relative)
    path.dirname.mkpath
    path.write(body)
  end

  test "ejecting copies our file where the site's copy is looked up first" do
    ejection = Nibble::Eject.run(@source, root: @root)

    assert_equal "site/cp/pages/cp/Dashboard.vue", ejection.target
    assert_equal "<template>ours</template>", @root.join(ejection.target).read
    assert_equal "<template>ours</template>", @root.join(@source).read, "ours must stay where it was"
  end

  test "the manifest records what was taken and when, so an upgrade can say what changed since" do
    Nibble::Eject.run(@source, root: @root)
    entry = Nibble::Eject.manifest(root: @root).fetch(@source)

    assert_equal "site/cp/pages/cp/Dashboard.vue", entry.target
    assert_equal Date.current.to_s, entry.at
    assert Nibble::Eject.ejected?(@source, root: @root)
  end

  test "a second eject refuses rather than discarding the site's edits" do
    Nibble::Eject.run(@source, root: @root)
    @root.join("site/cp/pages/cp/Dashboard.vue").write("<template>theirs</template>")

    error = assert_raises(Nibble::Eject::Refused) { Nibble::Eject.run(@source, root: @root) }
    assert_match "already exists", error.message
    assert_equal "<template>theirs</template>", @root.join("site/cp/pages/cp/Dashboard.vue").read

    Nibble::Eject.run(@source, root: @root, force: true)
    assert_equal "<template>ours</template>", @root.join("site/cp/pages/cp/Dashboard.vue").read
  end

  test "only files with somewhere to go can be ejected, so nothing lands outside site/" do
    write("vendor/nibble/lib/nibble/search.rb", "class Search; end")

    error = assert_raises(Nibble::Eject::Refused) { Nibble::Eject.run("vendor/nibble/lib/nibble/search.rb", root: @root) }
    assert_match "isn't a file a site can eject", error.message
  end

  test "a path that doesn't exist is refused before anything is written" do
    error = assert_raises(Nibble::Eject::Refused) { Nibble::Eject.run("vendor/nibble/frontend/nibble-cp/pages/cp/Gone.vue", root: @root) }

    assert_match "doesn't exist", error.message
    assert_not @root.join("config/nibble.yml").exist?, "a refused eject records nothing"
  end

  test "a copy is flagged once an upgrade replaces our original, so nobody silently misses a fix" do
    ejection = Nibble::Eject.run(@source, root: @root)
    assert_empty Nibble::Eject.stale(root: @root), "nothing is stale the moment it is ejected"

    @root.join(@source).write("<template>ours, from the next release</template>")

    assert_equal [ ejection.target ], Nibble::Eject.stale(root: @root).map(&:target)
  end

  test "a record without the original's checksum is never called stale, since there is nothing to compare" do
    Nibble::Metadata.write("ejected", { @source => { "target" => "site/cp/pages/cp/Dashboard.vue", "at" => "2026-01-01" } }, root: @root)
    @root.join(@source).write("<template>changed</template>")

    assert_empty Nibble::Eject.stale(root: @root)
  end

  test "an edit to one of our files without ejecting is reported, so it surfaces before an upgrade refuses" do
    release(@source => "<template>ours</template>", "vendor/nibble/lib/nibble/search.rb" => "class Search; end")
    assert_empty Nibble::Eject.unmanaged(root: @root), "an untouched install has nothing to report"

    @root.join("vendor/nibble/lib/nibble/search.rb").write("class Search; def hacked = true; end")

    assert_equal [ "vendor/nibble/lib/nibble/search.rb" ], Nibble::Eject.unmanaged(root: @root)
  end

  test "a file of ours the site deleted is reported, because the upgrade will stop on it" do
    release(@source => "<template>ours</template>", "vendor/nibble/lib/nibble/search.rb" => "class Search; end")
    @root.join("vendor/nibble/lib/nibble/search.rb").delete

    assert_equal [ "vendor/nibble/lib/nibble/search.rb" ], Nibble::Eject.unmanaged(root: @root)
  end

  test "files the site owns are never reported: what the installer wrote, what it added, and what it ejected" do
    release(@source => "<template>ours</template>")
    write("config/application.rb", "module Site; config.time_zone = 'Sydney'; end")
    write("app/models/invoice.rb", "class Invoice; end")
    Nibble::Eject.run(@source, root: @root)
    @root.join("site/cp/pages/cp/Dashboard.vue").write("<template>theirs</template>")

    assert_empty Nibble::Eject.unmanaged(root: @root)
  end

  test "a checkout no release came from has nothing to compare, so nothing is reported" do
    write("vendor/nibble/lib/nibble/search.rb", "class Search; def hacked = true; end")

    assert_empty Nibble::Eject.unmanaged(root: @root)
  end

  test "ejecting a second file keeps the first in the manifest" do
    write("vendor/nibble/frontend/nibble-cp/pages/cp/Confirm.vue", "<template>confirm</template>")
    Nibble::Eject.run(@source, root: @root)
    Nibble::Eject.run("vendor/nibble/frontend/nibble-cp/pages/cp/Confirm.vue", root: @root)

    assert_equal 2, Nibble::Eject.manifest(root: @root).size
  end
end

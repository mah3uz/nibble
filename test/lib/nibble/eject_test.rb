require "test_helper"

class Nibble::EjectTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir("nibble-eject"))
    @source = "vendor/nibble/frontend/nibble-admin/pages/admin/Dashboard.vue"
    write(@source, "<template>ours</template>")
  end

  teardown { FileUtils.rm_rf(@root) }

  def commit(message) = git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", message)

  def git(*args) = system("git", "-C", @root.to_s, *args, out: File::NULL, err: File::NULL)

  def write(relative, body)
    path = @root.join(relative)
    path.dirname.mkpath
    path.write(body)
  end

  test "ejecting copies our file where the site's copy is looked up first" do
    ejection = Nibble::Eject.run(@source, root: @root)

    assert_equal "site/cp/pages/admin/Dashboard.vue", ejection.target
    assert_equal "<template>ours</template>", @root.join(ejection.target).read
    assert_equal "<template>ours</template>", @root.join(@source).read, "ours must stay where it was"
  end

  test "the manifest records what was taken and when, so an upgrade can say what changed since" do
    Nibble::Eject.run(@source, root: @root)
    entry = Nibble::Eject.manifest(root: @root).fetch(@source)

    assert_equal "site/cp/pages/admin/Dashboard.vue", entry.target
    assert_equal Date.current.to_s, entry.at
    assert Nibble::Eject.ejected?(@source, root: @root)
  end

  test "a second eject refuses rather than discarding the site's edits" do
    Nibble::Eject.run(@source, root: @root)
    @root.join("site/cp/pages/admin/Dashboard.vue").write("<template>theirs</template>")

    error = assert_raises(Nibble::Eject::Refused) { Nibble::Eject.run(@source, root: @root) }
    assert_match "already exists", error.message
    assert_equal "<template>theirs</template>", @root.join("site/cp/pages/admin/Dashboard.vue").read

    Nibble::Eject.run(@source, root: @root, force: true)
    assert_equal "<template>ours</template>", @root.join("site/cp/pages/admin/Dashboard.vue").read
  end

  test "only files with somewhere to go can be ejected, so nothing lands outside site/" do
    write("vendor/nibble/lib/nibble/search.rb", "class Search; end")

    error = assert_raises(Nibble::Eject::Refused) { Nibble::Eject.run("vendor/nibble/lib/nibble/search.rb", root: @root) }
    assert_match "isn't a file a site can eject", error.message
  end

  test "a path that doesn't exist is refused before anything is written" do
    error = assert_raises(Nibble::Eject::Refused) { Nibble::Eject.run("vendor/nibble/frontend/nibble-admin/pages/admin/Gone.vue", root: @root) }

    assert_match "doesn't exist", error.message
    assert_not @root.join("config/nibble.yml").exist?, "a refused eject records nothing"
  end

  test "a copy is flagged once our original moves on, so nobody silently misses a fix" do
    git("init", "-q")
    git("add", "-A")
    commit("first")
    Nibble::Eject.run(@source, root: @root)
    ejection = Nibble::Eject.manifest(root: @root).fetch(@source)

    assert_empty Nibble::Eject.stale(root: @root), "nothing is stale the moment it is ejected"

    @root.join(@source).write("<template>ours, fixed</template>")
    git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-aqm", "fix")

    assert_equal [ ejection.target ], Nibble::Eject.stale(root: @root).map(&:target)
  end

  test "a manifest with no commit recorded is never called stale, since there is nothing to compare" do
    Nibble::Eject.run(@source, root: @root)

    assert_empty Nibble::Eject.stale(root: @root)
  end

  test "an edit to one of our files without ejecting is reported, so mistakes surface" do
    git("init", "-q")
    write("vendor/nibble/lib/nibble/search.rb", "class Search; end")
    git("add", "-A")
    commit("first")
    base = IO.popen([ "git", "-C", @root.to_s, "rev-parse", "HEAD" ], &:read).strip
    Nibble::Release.record_install(version: "0.1.0", commit: base, root: @root)

    assert_empty Nibble::Eject.unmanaged(root: @root), "an untouched install has nothing to report"

    @root.join("vendor/nibble/lib/nibble/search.rb").write("class Search; def hacked = true; end")
    git("add", "-A")
    commit("site edit")

    assert_equal [ "vendor/nibble/lib/nibble/search.rb" ], Nibble::Eject.unmanaged(root: @root)
  end

  test "a file the installer wrote is the site's to edit, so changing it is never reported" do
    git("init", "-q")
    write("config/application.rb", "module Site; end")
    write("Gemfile", %(eval_gemfile "vendor/nibble/Gemfile"))
    git("add", "-A")
    commit("first")
    base = IO.popen([ "git", "-C", @root.to_s, "rev-parse", "HEAD" ], &:read).strip
    Nibble::Release.record_install(version: "0.1.0", commit: base, root: @root)

    @root.join("config/application.rb").write("module Site; config.time_zone = 'Sydney'; end")
    @root.join("Gemfile").write(%(eval_gemfile "vendor/nibble/Gemfile"\ngem "money"))
    git("add", "-A")
    commit("site edits")

    assert_empty Nibble::Eject.unmanaged(root: @root)
  end

  test "an upgrade can show what changed upstream since a file was ejected" do
    git("init", "-q")
    git("add", "-A")
    commit("first")
    ejection = Nibble::Eject.run(@source, root: @root)

    assert_empty Nibble::Eject.diff_since(ejection, root: @root), "nothing has moved on yet"

    write(@source, "<template>ours, improved</template>")
    git("add", "-A")
    commit("our improvement")

    assert_includes Nibble::Eject.diff_since(ejection, root: @root), @source,
                    "a site cannot decide whether to take an improvement it cannot see"
  end

  test "a site's own files are not reported as edits to ours" do
    git("init", "-q")
    write("vendor/nibble/lib/nibble/search.rb", "class Search; end")
    git("add", "-A")
    commit("first")
    base = IO.popen([ "git", "-C", @root.to_s, "rev-parse", "HEAD" ], &:read).strip
    Nibble::Release.record_install(version: "0.1.0", commit: base, root: @root)

    write("vendor/nibble/lib/nibble/their_own.rb", "class TheirOwn; end")
    write("app/models/invoice.rb", "class Invoice; end")
    git("add", "-A")
    commit("the site writes its own")

    assert_empty Nibble::Eject.unmanaged(root: @root),
                 "a file only they have cannot conflict with ours, and app/ is theirs now"
  end

  test "a file of ours the site deleted is reported, because the upgrade will stop on it" do
    git("init", "-q")
    write("vendor/nibble/lib/nibble/search.rb", "class Search; end")
    git("add", "-A")
    commit("first")
    base = IO.popen([ "git", "-C", @root.to_s, "rev-parse", "HEAD" ], &:read).strip
    Nibble::Release.record_install(version: "0.1.0", commit: base, root: @root)

    @root.join("vendor/nibble/lib/nibble/search.rb").delete
    git("add", "-A")
    commit("the site removes one of ours")

    assert_equal [ "vendor/nibble/lib/nibble/search.rb" ], Nibble::Eject.unmanaged(root: @root)
  end

  test "a properly ejected copy is not reported as an accident" do
    git("init", "-q")
    git("add", "-A")
    commit("first")
    base = IO.popen([ "git", "-C", @root.to_s, "rev-parse", "HEAD" ], &:read).strip
    Nibble::Release.record_install(version: "0.1.0", commit: base, root: @root)
    Nibble::Eject.run(@source, root: @root)
    git("add", "-A")
    commit("ejected")

    assert_empty Nibble::Eject.unmanaged(root: @root), "site/ is theirs, so an override is never drift"
  end

  test "without a recorded install there is no baseline, so nothing is guessed" do
    assert_empty Nibble::Eject.unmanaged(root: @root)
  end

  test "ejecting a second file keeps the first in the manifest" do
    write("vendor/nibble/frontend/nibble-admin/pages/admin/Confirm.vue", "<template>confirm</template>")
    Nibble::Eject.run(@source, root: @root)
    Nibble::Eject.run("vendor/nibble/frontend/nibble-admin/pages/admin/Confirm.vue", root: @root)

    assert_equal 2, Nibble::Eject.manifest(root: @root).size
  end
end

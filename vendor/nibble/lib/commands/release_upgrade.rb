require "tmpdir"

# Takes a release into this checkout: snapshot, merge, re-render, migrate.
module ReleaseUpgrade
  private

  def take_release(version)
    $stdout.sync = true
    # Refuse before booting: a deployed environment would fail on its own credentials rather than say why.
    environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
    fail!("upgrade on a workstation and deploy the result; never in place on #{environment}") unless environment == "development"

    boot_application!
    fail!("working tree isn't clean") unless git_out("status", "--porcelain").empty?

    installed = Nibble::Release.installed or fail!("no install record in #{Nibble::Release::RECORD}; this checkout was not installed by nibble:install")

    repository = ENV.fetch("NIBBLE_REPO", Nibble::REPOSITORY)
    step "fetching releases from #{repository}"
    git("fetch", "--tags", repository) or fail!("could not fetch")

    target = version ? (version.start_with?("v") ? version : "v#{version}") : Nibble::Release.latest
    fail!("no releases to upgrade to") if target.blank?
    taken = Nibble::Release.declared(target)
    fail!("#{target} is #{taken.version}, which this install is already on") if taken.version == installed.version

    step "#{installed.version} → #{taken.version}"
    blockers = Nibble::Release.blockers(from: installed.version, release: taken)
    if blockers.any?
      blockers.each { |blocker| warn "  ✗ #{blocker.reason}" }
      fail!("#{taken.version} cannot be taken yet")
    end

    step "snapshotting the database"
    database = ActiveRecord::Base.connection_db_config.database
    snapshot = root.join("storage", "upgrades", "#{Time.current.strftime('%Y-%m-%d-%H%M%S')}-#{installed.version}.sqlite3")
    snapshot.dirname.mkpath
    ActiveRecord::Base.connection.execute("VACUUM INTO #{ActiveRecord::Base.connection.quote(snapshot.to_s)}")
    puts "  #{snapshot.relative_path_from(root)}"
    puts "  restore it with: cp #{snapshot.relative_path_from(root)} #{database}"

    step "merging #{target}"
    # A site's history always diverges from the release line, so merge.ff=only must not decide this.
    unless git("-c", "merge.ff=true", "merge", "--no-edit", target)
      if root.join(".git/MERGE_HEAD").exist?
        warn "\nthe merge stopped on conflicts in files this site has changed."
        warn "resolve them and commit, or put everything back with: git merge --abort"
      else
        warn "\ngit would not merge #{target}, and nothing here has changed."
      end
      exit 1
    end

    # The release's commit, not the merge commit, which would absorb a site's edits to our files.
    Nibble::Release.record_install(version: taken.version, commit: git_out("rev-parse", "#{target}^{commit}"))

    step "files a site owns, generated from our templates"
    offer_regenerated(installed)

    step "files this site ejected"
    stale = Nibble::Eject.stale
    puts "  none out of date" if stale.empty?
    stale.each do |ejection|
      puts "  #{ejection.target} — ours changed since you copied it on #{ejection.at}"
      puts Nibble::Eject.diff_since(ejection).lines.map { |line| "    #{line}" }.join
      puts "    see it all with: git diff #{ejection.commit} HEAD -- #{ejection.source}"
    end

    step "installing dependencies"
    system("bundle", "install", chdir: root.to_s) or fail!("bundle install failed; the merge is still here, and git merge --abort undoes it")
    # package-lock.json is shared, so rebuild it rather than install from it.
    system("npm", "install", chdir: root.to_s) or fail!("installing npm packages failed; the merge is still here, and git merge --abort undoes it")

    step "migrating"
    puts "  past this point the merge is committed; the way back is the snapshot above"
    unless system(root.join("bin/rails").to_s, "nibble:prepare", chdir: root.to_s)
      warn "\nthe code is on #{taken.version}; the database is not."
      warn "fix what it reported, then run bin/rails nibble:prepare again."
      warn "if the database was left part way, put it back first with:"
      warn "  cp #{snapshot.relative_path_from(root)} #{database}"
      exit 1
    end

    step "on #{taken.version}"
    puts "  run bin/ci, look over the site, then commit and deploy"
    puts "  the snapshot stays at #{snapshot.relative_path_from(root)} until you remove it"
  end

  def offer_regenerated(installed)
    regenerated = Nibble::Install.outdated(since: installed.commit, answers: installed.answers, version: installed.version)
    return puts("  this install predates recorded answers, so ours cannot be re-rendered; compare them by hand") if installed.answers.blank?
    return puts("  none changed") if regenerated.empty?

    take_all = false
    regenerated.each do |file|
      answer = take_all ? "y" : nil
      until %w[y n a q].include?(answer)
        puts "\n  #{file.destination} — our template has moved on"
        print "  [y] take ours  [n] keep yours  [d] show the difference  [a] take every one  [q] leave the rest: "
        answer = $stdin.tty? ? $stdin.gets.to_s.strip.downcase : "n"
        puts "n (nothing is typed here without a terminal)" unless $stdin.tty?
        puts diff(file.current, file.rendered) if answer == "d"
      end
      break if answer == "q"

      take_all ||= answer == "a"
      next if answer == "n"

      root.join(file.destination).write(file.rendered)
      puts "  wrote #{file.destination} — git diff shows what it replaced"
    end
  end

  def fail!(message) = abort("upgrade refused: #{message}")

  def step(title) = puts("\n#{title}")

  def root = Rails.root

  def diff(mine, theirs)
    Dir.mktmpdir do |dir|
      [ [ "yours", mine ], [ "ours", theirs ] ].each { |name, body| File.write(File.join(dir, name), body) }
      IO.popen([ "git", "diff", "--no-index", "--", "#{dir}/yours", "#{dir}/ours" ], err: File::NULL, &:read)
        .lines.drop(4).map { |line| "  #{line}" }.join
    end
  end

  def git(*args) = system("git", "-C", root.to_s, *args)

  def git_out(*args) = IO.popen([ "git", "-C", root.to_s, *args ], err: File::NULL, &:read).strip
end

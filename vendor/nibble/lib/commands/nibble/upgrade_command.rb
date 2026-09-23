require "tmpdir"
require_relative "../clean_failures"

# The part of an upgrade that needs the new release running: bin/upgrade calls it once vendor/nibble is swapped.
class NibbleUpgradeCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:upgrade"

  desc "finish PREVIOUS", "Offer the site files whose templates moved on, report stale ejections, record the release", hide: true
  def finish(previous)
    boot_application!
    previous = Pathname(previous)
    installed = Nibble::Release.installed or abort("config/nibble.yml has no install record")

    step "files a site owns, written from our templates"
    offer(installed, previous.join("templates"))

    step "screens this site ejected"
    stale = Nibble::Eject.stale
    puts "  none changed" if stale.empty?
    stale.each do |ejection|
      puts "  #{ejection.target} — ours changed since you copied it on #{ejection.at}"
      before = previous.join(ejection.source.delete_prefix("vendor/nibble/"))
      puts diff(before.file? ? before.read : "", Rails.root.join(ejection.source).read)
    end

    Nibble::Release.record_install(version: Nibble::VERSION)
    puts "\n  config/nibble.yml records #{Nibble::VERSION}"
  end

  private

  def offer(installed, templates)
    return puts("  this install has no recorded answers, so ours cannot be written again; compare them by hand") if installed.answers.blank?

    files = Nibble::Install.outdated(previous: templates, answers: installed.answers, version: installed.version)
    return puts("  none changed") if files.empty?

    take_all = false
    files.each do |file|
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

      Rails.root.join(file.destination).write(file.rendered)
      puts "  wrote #{file.destination}"
    end
  end

  def step(title) = puts("\n#{title}")

  def diff(before, after)
    Dir.mktmpdir do |dir|
      [ [ "before", before ], [ "after", after ] ].each { |name, body| File.write(File.join(dir, name), body) }
      IO.popen([ "diff", "-u", "#{dir}/before", "#{dir}/after" ], err: File::NULL, &:read)
        .lines.drop(2).map { |line| "    #{line}" }.join
    end
  end
end

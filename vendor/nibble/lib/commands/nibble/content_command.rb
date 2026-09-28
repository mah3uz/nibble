require_relative "../clean_failures"

class NibbleContentCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:content"

  desc "validate DIR", "Check a content package without writing anything"
  def validate(dir)
    boot_application!
    report = Nibble::Packages::Importer.new(dir).validate
    report.errors.each { |error| puts "✗ #{error}" }
    abort "content package has #{report.errors.size} problem(s)" unless report.ok?
    puts "content package is valid"
  end

  desc "import DIR", "Import a content package, validating everything first"
  option :mode, default: "create", enum: %w[create update], desc: "create adds what's missing; update also refreshes what's there"
  option :dry_run, type: :boolean, desc: "List what would be created and updated, and write nothing"
  option :webhooks, type: :boolean, desc: "Deliver webhooks for the imported changes"
  def import(dir)
    boot_application!
    importer = Nibble::Packages::Importer.new(dir, mode: options[:mode], notify: options[:webhooks] && !options[:dry_run])
    report = options[:dry_run] ? importer.preview : importer.call
    report.errors.each { |error| puts "✗ #{error}" }
    abort "nothing imported: #{report.errors.size} problem(s)" unless report.ok?
    if options[:dry_run]
      report.created.each { |file| puts "+ #{file}" }
      report.updated.each { |file| puts "~ #{file}" }
      puts "dry run, nothing written: would create #{report.created.size}, update #{report.updated.size}, " \
        "and leave #{report.skipped.size} as they were"
    else
      Nibble::Events.dispatch_pending
      puts "created #{report.created.size}, updated #{report.updated.size}, left #{report.skipped.size} as they were"
    end
  end

  desc "export DIR", "Export this site's content as a package"
  option :collections, desc: "Only these collections, comma-separated"
  option :taxonomies, desc: "Only these taxonomies, comma-separated"
  option :locales, desc: "Only these locales, comma-separated"
  option :status, enum: %w[published draft], desc: "Only entries with this status"
  def export(dir)
    boot_application!
    list = ->(name) { options[name]&.split(",")&.map(&:strip) }
    files = Nibble::Packages::Exporter.new(dir, collections: list.call(:collections), taxonomies: list.call(:taxonomies),
      locales: list.call(:locales), status: options[:status]).call
    puts files
    puts "#{files.size} file(s) written to #{dir}"
  end

  desc "migrate", "Run pending content migrations from site/schema/migrations"
  option :dry_run, type: :boolean, desc: "Print what would change, then roll everything back"
  def migrate
    boot_application!
    results = Nibble::ContentMigrations.run(dry_run: options[:dry_run])
    results.each do |result|
      puts result.name
      result.counts.each { |label, count| puts "  #{label}: #{count}" }
    end
    Nibble::Events.dispatch_pending unless options[:dry_run]
    puts results.empty? ? "no pending content migrations" : "#{options[:dry_run] ? 'dry run, nothing written' : 'ran'}: #{results.size} migration(s)"
  end

  private

  def report(result)
    result.report.errors.each { |error| puts "✗ #{error}" }
    abort "#{result.collection}: nothing written, #{result.report.errors.size} problem(s)" unless result.ok?

    puts "#{result.collection}: created #{result.report.created.size}, updated #{result.report.updated.size}, " \
         "trashed #{result.trashed.size}"
  end
end

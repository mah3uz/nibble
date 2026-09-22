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

  desc "import [DIR]", "Import a content package, validating everything first (the active theme's package by default)"
  option :mode, default: "create", enum: %w[create update], desc: "create adds what's missing; update also refreshes what's there"
  option :dry_run, type: :boolean, desc: "Validate and report without writing anything"
  option :webhooks, type: :boolean, desc: "Deliver webhooks for the imported changes"
  def import(dir = nil)
    boot_application!
    dir ||= Nibble.config.theme_path&.join("content")&.to_s or abort "a package directory is required (no active theme content)"
    report = Nibble::Packages::Importer.new(dir, mode: options[:mode], dry_run: options[:dry_run], notify: options[:webhooks]).call
    report.errors.each { |error| puts "✗ #{error}" }
    abort "nothing imported: #{report.errors.size} problem(s)" unless report.ok?
    Nibble::Events.dispatch_pending
    if options[:dry_run]
      puts "dry run: package is valid"
    else
      puts "created #{report.created.size}, updated #{report.updated.size}, left #{report.skipped.size} as they were"
    end
  end

  desc "markdown [COLLECTION]", "Make every collection written as Markdown match its folder (all of them by default)"
  option :dry_run, type: :boolean, desc: "Report what would change without writing anything"
  def markdown(collection = nil)
    boot_application!
    handles = collection ? [ collection ] : Nibble::Packages::Folder.declared.map(&:handle)
    # Syncing every folder when a site has none is nothing to do, not a failure: this runs at every boot.
    return puts "no collection is written as Markdown" if handles.empty?

    handles.each { |handle| report(Nibble::Packages::Folder.for(handle, dry_run: !!options[:dry_run]).call) }
    Nibble::Events.dispatch_pending
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

  desc "migrate", "Run pending content migrations from schema/migrations"
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

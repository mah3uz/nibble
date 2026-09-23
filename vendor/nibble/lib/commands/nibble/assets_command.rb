require_relative "../clean_failures"

class NibbleAssetsCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:assets"

  desc "purge_unused", "List assets nothing uses and uploaded files no asset owns; --confirm acts on the list"
  option :older_than_days, type: :numeric, default: 1, desc: "Only what was uploaded at least this many days ago"
  option :confirm, type: :boolean, desc: "Move the unused assets to the trash and delete the stray files"
  def purge_unused
    boot_application!
    days = options[:older_than_days]
    cutoff = days.days.ago
    assets = Nibble::Assets.unused(before: cutoff).to_a
    strays = Nibble::Assets.stray_blobs(before: cutoff).to_a

    assets.each do |asset|
      Nibble::Lifecycle.call(asset, :trash) if options[:confirm]
      puts "#{options[:confirm] ? 'trashed' : 'unused'}  #{[ asset.folder.presence, asset.filename ].compact.join('/')} (#{asset.size} bytes)"
    end
    strays.each do |blob|
      blob.purge if options[:confirm]
      puts "#{options[:confirm] ? 'deleted' : 'stray'}    #{blob.filename} (#{blob.byte_size} bytes, uploaded #{blob.created_at.to_date})"
    end

    summary = "#{assets.size} unused #{'asset'.pluralize(assets.size)} and #{strays.size} stray #{'file'.pluralize(strays.size)} " \
              "older than #{days} #{'day'.pluralize(days)}"
    puts options[:confirm] ? "#{summary}: assets moved to the trash, files deleted" : "#{summary}; run with --confirm to act on them"
  end
end

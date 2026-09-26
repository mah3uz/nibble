require_relative "../clean_failures"

class NibbleDevCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:dev"

  desc "seed", "Add realistic demo posts, authors and topics to a development database (safe to re-run)"
  option :posts, type: :numeric, default: 120, desc: "Demo posts to add"
  def seed
    boot_application!
    abort "nibble:dev:seed only runs in development" unless Rails.env.development?

    images = Nibble::Records::Asset.kept.where(kind: "image").select { |asset| asset.width.to_i > asset.height.to_i && asset.width.to_i >= 600 }
    created = Nibble::DemoContent.new(images:, actor: Nibble::User.administrators.first).seed(options[:posts])
    Nibble::Events.dispatch_pending
    Nibble::Search.rebuild
    puts "created #{created} posts · #{Nibble::Records::Entry.kept.where(collection: 'posts').group(:status).count.map { |status, count| "#{count} #{status}" }.join(', ')}"
  rescue Nibble::Error => e
    abort e.message
  end
end

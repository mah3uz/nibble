require_relative "../clean_failures"

class NibbleGenerateCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:generate"

  desc "theme HANDLE", "Copy the starter theme into themes/HANDLE and make it this site's"
  def theme(handle)
    boot_application!
    Nibble::Generate.theme(handle).each do |written|
      puts "wrote #{written.path}"
      puts "  #{written.note}" if written.note
    end
    install_workspace
    puts "run bin/rails nibble:check"
  rescue Nibble::Generate::Refused => e
    abort "generate refused: #{e.message}"
  end

  desc "view NAME", "Write a view and its query sidecar into this site's theme"
  option :collection, type: :string, desc: "The collection its query reads, and the record it is typed for"
  def view(name)
    boot_application!
    Nibble::Generate.view(name, collection: options[:collection]).each do |written|
      puts "wrote #{written.path}"
      puts "  #{written.note}" if written.note
    end
    refresh_types
    puts "run bin/rails nibble:check"
  rescue Nibble::Generate::Refused => e
    abort "generate refused: #{e.message}"
  end

  %w[collection taxonomy blueprint fieldset global navigation form plugin].each do |kind|
    desc kind, "Write a #{kind} stub into the site's own schema"
    define_method(kind) do |handle|
      boot_application!
      Nibble::Generate.public_send(kind, handle).each { |written| puts "wrote #{written.path}" }
      refresh_types
      puts "run bin/rails nibble:check"
    rescue Nibble::Generate::Refused => e
      abort "generate refused: #{e.message}"
    end
  end

  private

  # A new theme leaves package-lock.json out of date, and npm ci then fails far from here.
  def install_workspace
    puts "registering the theme with npm"
    return puts "  npm install failed — run it yourself before building" unless system("npm", "install", "--silent")

    puts "  package-lock.json now knows about it; commit it with the theme"
  end

  # A new collection changes the theme's generated types, so leaving them stale would fail nibble:check.
  def refresh_types
    Nibble.reset_schema!
    output = Nibble::TypeGenerator.write! or return
    puts "wrote #{output.relative_path_from(Rails.root)}"
  end
end

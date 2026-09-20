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
    puts "run npm install, then bin/rails nibble:check"
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

  # A new collection changes the theme's generated types, so leaving them stale would fail nibble:check.
  def refresh_types
    Nibble.reset_schema!
    output = Nibble::TypeGenerator.theme_output or return
    output.dirname.mkpath
    output.write(Nibble::TypeGenerator.new.generate)
    puts "wrote #{output.relative_path_from(Rails.root)}"
  end
end

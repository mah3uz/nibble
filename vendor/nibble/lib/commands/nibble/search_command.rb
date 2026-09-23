require_relative "../clean_failures"

class NibbleSearchCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:search"

  desc "rebuild", "Rebuild every search index from live content"
  def rebuild
    boot_application!
    Nibble::Search.rebuild
    puts "nibble search indexes rebuilt"
  end
end

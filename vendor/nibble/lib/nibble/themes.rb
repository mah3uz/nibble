module Nibble
  # The visitor's light or dark choice, which the shell renders so the first paint already matches it.
  module Themes
    COOKIE = "nibble_theme".freeze
    CHOICES = %w[light dark].freeze

    # Allowlisted because the value reaches an HTML attribute.
    def self.chosen(cookies) = CHOICES.find { |choice| choice == cookies[COOKIE] }
  end
end

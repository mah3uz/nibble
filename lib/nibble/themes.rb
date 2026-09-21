module Nibble
  # The visitor's light or dark choice, which the shell renders so the first paint already matches it.
  module Themes
    COOKIE = "nibble_theme".freeze
    CHOICES = %w[light dark].freeze

    # Anything else is treated as no choice at all: the value reaches an HTML attribute, and a theme's
    # stylesheet decides what data-theme means, so only the two registers Nibble defines are passed through.
    def self.chosen(cookies) = CHOICES.find { |choice| choice == cookies[COOKIE] }
  end
end

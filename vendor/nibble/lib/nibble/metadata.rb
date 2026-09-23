module Nibble
  # Nibble's record of a site — the release it is on, how it was installed, what it ejected — kept at the end of
  # config/nibble.yml. Only the part after the marker is ever rewritten, so a person's settings and comments survive.
  module Metadata
    FILE = "config/nibble.yml".freeze
    MARKER = "# Written by Nibble from here to the end of the file. Your settings go above this line.".freeze

    class << self
      def read(root: Rails.root)
        file = root.join(FILE)
        return {} unless file.file?

        _, found, record = file.read.partition(MARKER)
        found.empty? ? {} : YAML.safe_load(record).to_h
      end

      def write(key, value, root: Rails.root)
        file = root.join(FILE)
        record = read(root:).merge(key.to_s => value)
        above = settings(file.file? ? file.read : "").rstrip
        file.dirname.mkpath
        file.write([ above.presence, "#{MARKER}\n#{record.to_yaml.delete_prefix("---\n")}" ].compact.join("\n\n"))
      end

      # A site's settings alone, so nothing that edits or reads them by hand mistakes the record for them.
      def settings(text) = text.partition(MARKER).first
    end
  end
end

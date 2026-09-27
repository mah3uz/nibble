module Nibble
  # The links a page may carry: themes put them straight into href, where javascript: or data: would run.
  module SafeUrl
    PATTERN = %r{\A(?:https?://|mailto:|tel:|/|\#|\?)}i

    module_function

    def safe?(value) = value.to_s.strip.match?(PATTERN)
  end
end

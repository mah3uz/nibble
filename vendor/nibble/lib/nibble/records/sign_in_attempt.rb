module Nibble
  module Records
    class SignInAttempt < Nibble::ApplicationRecord
      self.table_name = "nibble_sign_in_attempts"
    end
  end
end

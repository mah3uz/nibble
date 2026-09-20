module Nibble
  module Records
    class SignInAttempt < ::ApplicationRecord
      self.table_name = "sign_in_attempts"
    end
  end
end

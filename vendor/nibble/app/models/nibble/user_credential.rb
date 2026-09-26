module Nibble
  class UserCredential < Nibble::ApplicationRecord
    self.table_name = "nibble_user_credentials"

    belongs_to :user

    validates :external_id, presence: true, uniqueness: true
    validates :name, presence: true
  end
end

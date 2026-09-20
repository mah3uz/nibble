class Session < ApplicationRecord
  belongs_to :user

  before_create { self.elevated_at ||= Time.current }
end

class Current < ActiveSupport::CurrentAttributes
  attribute :session, :media_usages
  delegate :user, to: :session, allow_nil: true
end

module Nibble
  class Current < ActiveSupport::CurrentAttributes
    attribute :ip, :schema_checked, :content_checked, :session, :media_usages
    delegate :user, to: :session, allow_nil: true
  end
end

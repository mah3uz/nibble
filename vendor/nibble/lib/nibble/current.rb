module Nibble
  class Current < ActiveSupport::CurrentAttributes
    attribute :ip, :schema_checked, :content_checked
  end
end

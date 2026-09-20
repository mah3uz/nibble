module Nibble
  class Current < ActiveSupport::CurrentAttributes
    attribute :ip, :schema_checked
  end
end

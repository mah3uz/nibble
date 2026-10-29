module Nibble
  module Fieldtypes
    class ButtonGroup < Radio
      self.config_field_items = [
        { "display" => "Selection & Options", "fields" => { "options" => { "type" => "list", "default" => [] } } },
        { "display" => "Data & Format", "fields" => { "cast_booleans" => { "type" => "toggle", "default" => false } } }
      ]
    end
  end
end

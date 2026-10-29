module Nibble
  module Fieldtypes
    class ButtonGroup < Radio
      self.config_field_items = [
        { "display" => "Selection and options", "fields" => { "options" => { "type" => "list", "default" => [] } } },
        { "display" => "Data and format", "fields" => { "cast_booleans" => { "type" => "toggle", "default" => false } } }
      ]
    end
  end
end

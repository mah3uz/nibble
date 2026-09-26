module Nibble
  module Records
    # Polymorphic columns store short record types ("entry"), not Ruby class names, so content survives renames.
    module TypedPolymorphism
      extend ActiveSupport::Concern

      class_methods do
        def polymorphic_class_for(name) = name == "user" ? Nibble::User : Records.model(name)
      end
    end
  end
end

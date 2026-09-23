ActiveSupport.on_load(:active_storage_attachment) do
  def self.polymorphic_class_for(name) = Nibble::Records::MODELS.key?(name) ? Nibble::Records.model(name) : super
end

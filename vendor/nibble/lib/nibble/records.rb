module Nibble
  module Records
    MODELS = {
      "entry" => "Nibble::Records::Entry",
      "term" => "Nibble::Records::Term",
      "global" => "Nibble::Records::GlobalSet",
      "navigation" => "Nibble::Records::NavigationTree",
      "asset" => "Nibble::Records::Asset",
      "form_submission" => "Nibble::Records::FormSubmission",
      "webhook_delivery" => "Nibble::Records::WebhookDelivery"
    }.freeze

    def self.model(type) = MODELS.fetch(type.to_s) { raise Error, "unknown record type '#{type}'" }.constantize
  end
end

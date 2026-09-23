module Nibble
  module Fieldtypes
    class Files < Fieldtype
      DEFAULT_EXTENSIONS = %w[pdf doc docx xls xlsx csv txt jpg jpeg png gif webp heic].freeze
      KEYS = %w[id filename size content_type].freeze

      self.selectable = false
      self.selectable_in_forms = true
      self.localizable = false
      self.defaultable = false
      self.categories = %w[media]
      self.keywords = %w[file upload attachment]
      self.contract_samples = [ [ { "id" => 1, "filename" => "cv.pdf", "size" => 2048, "content_type" => "application/pdf" } ], nil ]
      self.config_field_items = [
        { "display" => "Boundaries & Limits", "fields" => {
          "max_files" => { "type" => "integer", "default" => 1, "width" => 50 },
          "max_file_size" => { "type" => "integer", "default" => 10, "instructions" => "In megabytes.", "width" => 50 },
          "extensions" => { "type" => "list", "default" => DEFAULT_EXTENSIONS }
        } }
      ]

      def pre_process_validatable(value) = Array.wrap(value).compact_blank

      def process(value)
        stored = Array.wrap(value).select { |item| item.is_a?(Hash) }.map { |item| item.stringify_keys.slice(*KEYS) }
        stored.presence
      end

      def augment(value) = process(value) || []

      def rules
        [
          "array",
          *("max:#{config('max_files')}" if config("max_files").to_i.positive?),
          "mimes:#{Array(config('extensions')).join(',')}",
          *("max_file_size:#{config('max_file_size')}" if config("max_file_size").to_i.positive?)
        ]
      end

      def ts_type = "{ id: number; filename: string; size: number; content_type: string }[]"
    end
  end
end

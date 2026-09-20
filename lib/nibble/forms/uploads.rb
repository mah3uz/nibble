module Nibble
  module Forms
    module Uploads
      DENIED_EXTENSIONS = %w[
        html htm xhtml shtml svg svgz xml xsl js mjs cjs css swf php phtml asp aspx jsp cgi pl py rb sh bash zsh
        exe com bat cmd msi msp scr dll cpl jar apk app dmg pkg deb rpm ps1 psm1 vbs vbe wsf wsh hta lnk reg iso img
        docm dotm xlsm xltm xlam pptm potm ppam sldm
      ].freeze
      TEXT_TYPES = %w[text/plain text/csv].freeze
      OLE = "application/x-ole-storage".freeze
      OLE_TYPES = %w[application/msword application/vnd.ms-excel application/vnd.ms-powerpoint].freeze
      MAX_FILES = 10
      MAX_FILE_SIZE_MB = 25
      SNIFF_BYTES = 8.kilobytes

      module_function

      def file?(value) = value.respond_to?(:original_filename) && value.respond_to?(:tempfile)

      def extension(value) = File.extname(value.original_filename.to_s).delete_prefix(".").downcase

      def allowed?(value, extensions)
        return false unless file?(value) && value.size.positive?

        ext = extension(value)
        return false if DENIED_EXTENSIONS.include?(ext) || !extensions.map { |item| item.to_s.downcase }.include?(ext)

        content_type(value).present?
      end

      def content_type(value)
        claimed = Marcel::MimeType.for(name: value.original_filename.to_s)
        io = value.tempfile.tap(&:rewind)
        detected = Marcel::MimeType.for(io)
        io.rewind
        return (text?(io) ? claimed : nil).tap { io.rewind } if TEXT_TYPES.include?(claimed)
        return nil if detected == "application/octet-stream"
        return claimed if detected == claimed || Marcel::Magic.child?(claimed, detected) || (detected == OLE && OLE_TYPES.include?(claimed))

        nil
      end

      def text?(io)
        sample = io.read(SNIFF_BYTES).to_s
        !sample.include?("\x00") && sample.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      end

      def store(value)
        blob = ActiveStorage::Blob.create_and_upload!(io: value.tempfile.tap(&:rewind), identify: false,
          filename: ActiveStorage::Filename.new(File.basename(value.original_filename.to_s)).sanitized, content_type: content_type(value))
        { "id" => blob.id, "filename" => blob.filename.to_s, "size" => blob.byte_size, "content_type" => blob.content_type }
      end

      def request_limit(form)
        fields = form.fields.all.values.select { |field| field.type == "files" }
        fields.sum { |field| field.fieldtype.config("max_files").to_i * field.fieldtype.config("max_file_size").to_i.megabytes } + 1.megabyte
      end

      def problems(form, schema: Nibble.schema)
        form.fields(schema:).all.values.select { |field| field.type == "files" }.flat_map do |field|
          fieldtype = field.fieldtype
          problems = []
          problems << "field '#{field.handle}' needs the form to store submissions, which is where its files are kept" unless form.store?
          problems << "field '#{field.handle}' max_files must be between 1 and #{MAX_FILES}" unless (1..MAX_FILES).cover?(fieldtype.config("max_files").to_i)
          unless (1..MAX_FILE_SIZE_MB).cover?(fieldtype.config("max_file_size").to_i)
            problems << "field '#{field.handle}' max_file_size must be between 1 and #{MAX_FILE_SIZE_MB} MB"
          end
          denied = Array(fieldtype.config("extensions")).map { |item| item.to_s.downcase } & DENIED_EXTENSIONS
          problems << "field '#{field.handle}' can't accept #{denied.join(', ')} files from the public" if denied.any?
          problems
        end
      end
    end
  end
end

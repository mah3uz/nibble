require "zip"

module Nibble
  module Packages
    module Archive
      EXTENSIONS = %w[.yml .yaml .json].freeze
      MAX_FILES = 20_000
      MAX_BYTES = 200 * 1024 * 1024
      TOP_LEVEL = %w[collections taxonomies globals navigation redirects.yml redirects.json assets.yml assets.json].freeze

      module_function

      def write(dir)
        root = Pathname(dir)
        buffer = Zip::OutputStream.write_buffer do |zip|
          Dir.glob("**/*", base: root).sort.each do |relative|
            next unless root.join(relative).file?

            zip.put_next_entry(relative)
            zip.write(root.join(relative).binread)
          end
        end
        buffer.string
      end

      def extract(io, into:, max_files: MAX_FILES, max_bytes: MAX_BYTES)
        root = Pathname(into)
        Zip::File.open_buffer(io) do |zip|
          entries = zip.entries.reject { |entry| entry.directory? || entry.name.start_with?("__MACOSX/") }
          raise Error, "the package has more than #{max_files} files" if entries.size > max_files
          raise Error, "the package unpacks to more than #{max_bytes / 1024 / 1024} MB" if entries.sum(&:size) > max_bytes

          entries.each do |entry|
            raise Error, "#{entry.name} is a link, which a package can't contain" if entry.symlink?

            safe_path(entry.name)
          end

          prefix = wrapper_folder(entries)
          entries.each do |entry|
            relative = safe_path(entry.name.delete_prefix(prefix))
            next unless EXTENSIONS.include?(File.extname(relative).downcase)

            target = root.join(relative)
            target.dirname.mkpath
            target.binwrite(entry.get_input_stream.read)
          end
        end
        root
      rescue Zip::Error => e
        raise Error, "that isn't a readable zip file (#{e.message})"
      end

      # Compressing a folder puts everything under that folder's name; a package starts one level down.
      def wrapper_folder(entries)
        tops = entries.map { |entry| entry.name.split("/").first }.uniq
        return "" unless tops.size == 1 && tops.first.present? && !TOP_LEVEL.include?(tops.first)

        entries.all? { |entry| entry.name.include?("/") } ? "#{tops.first}/" : ""
      end

      def safe_path(name)
        parts = name.tr("\\\\", "/").split("/")
        if name.start_with?("/") || name.match?(/\A[A-Za-z]:/) || parts.include?("..") || parts.empty?
          raise Error, "#{name} points outside the package"
        end

        parts.reject { |part| part.empty? || part == "." }.join("/")
      end
    end
  end
end

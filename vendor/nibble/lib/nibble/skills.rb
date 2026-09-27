module Nibble
  # Skills served over MCP through the io.modelcontextprotocol/skills extension. Each file is a skill:// resource, and
  # a skill's entry lists every file's digest and size, computed from the bytes served, so a client can verify reads.
  module Skills
    EXTENSION = "io.modelcontextprotocol/skills".freeze
    Unknown = Class.new(ArgumentError)

    Skill = Data.define(:name, :files) do
      def uri(path = "SKILL.md") = "skill://#{name}/#{path}"
    end

    module_function

    def bundled
      Nibble.core_root.join("skills").children.select(&:directory?).sort.map do |dir|
        Skill.new(dir.basename.to_s, dir.glob("**/*").select(&:file?).sort.to_h { |path| [ path.relative_path_from(dir).to_s, path.binread ] })
      end
    end

    def entry(skill)
      { "uri" => skill.uri, "frontmatter" => frontmatter(skill.files.fetch("SKILL.md")),
        "resources" => skill.files.map { |path, bytes| { "uri" => skill.uri(path), "digest" => "sha256:#{Digest::SHA256.hexdigest(bytes)}", "size" => bytes.bytesize } } }
    end

    def get(skills, uri) = entry(skills.find { |skill| skill.uri == uri } || raise(Unknown, "there is no skill at #{uri}"))

    def read(skills, uri)
      skill = skills.find { |candidate| uri.to_s.start_with?(candidate.uri("")) }
      bytes = skill&.files&.[](uri.delete_prefix(skill.uri(""))) or raise Unknown, "there is no resource at #{uri}"
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      { "uri" => uri, "mimeType" => mime_type(uri) }.merge(text.valid_encoding? ? { "text" => text } : { "blob" => Base64.strict_encode64(bytes) })
    end

    def resource(skill)
      { "uri" => skill.uri, "name" => skill.name, "description" => frontmatter(skill.files.fetch("SKILL.md"))["description"], "mimeType" => "text/markdown" }
    end

    def frontmatter(markdown)
      yaml = markdown.dup.force_encoding(Encoding::UTF_8)[/\A---\n(.*?)\n---\n/m, 1] or raise ArgumentError, "SKILL.md must begin with frontmatter"
      YAML.safe_load(yaml).to_h
    end

    def mime_type(uri) = File.extname(uri) == ".md" ? "text/markdown" : Rack::Mime.mime_type(File.extname(uri), "text/plain")
  end
end

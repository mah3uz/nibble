require_relative "../clean_failures"

class NibbleSchemaCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:schema"

  desc "show [KEY]", "Print the effective schema (core → theme → site), or one item as YAML, e.g. collections/posts"
  def show(key = nil)
    boot_application!
    schema = Nibble.schema
    if key
      item = schema.items.find { |candidate| candidate.key == key } or abort "No schema item #{key}"
      puts "# #{item.key} (#{item.layer}: #{item.path.relative_path_from(Rails.root)})"
      puts item.data.to_yaml
    else
      width = schema.items.map { |item| item.key.size }.max.to_i
      schema.items.sort_by(&:key).each do |item|
        puts "#{item.key.ljust(width)}  #{item.layer.to_s.ljust(5)}  #{item.path.relative_path_from(Rails.root)}"
      end
    end
  end

  desc "snapshot", "Record the schema's field types, so nibble:check can catch a later type change that strands data"
  def snapshot
    boot_application!
    puts Nibble::Drift.record_snapshot! ? "schema snapshot recorded" : "schema unchanged since the last snapshot"
  end

  desc "types", "Generate TypeScript types for schema-defined content (the active theme's .nibble/types.d.ts by default)"
  option :output, desc: "Write the types here instead"
  def types
    boot_application!
    output = if options[:output]
      Rails.root.join(options[:output])
    else
      Nibble::TypeGenerator.theme_output || Rails.root.join("tmp/nibble/schema.d.ts")
    end
    FileUtils.mkdir_p(output.dirname)
    output.write(Nibble::TypeGenerator.new.generate)
    puts "Wrote #{output.relative_path_from(Rails.root)}"
  end
end

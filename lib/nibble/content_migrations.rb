module Nibble
  module ContentMigrations
    Migration = Data.define(:name, :path, :operations)
    Result = Data.define(:name, :counts)

    module_function

    def pending
      ran = Records::ContentMigration.pluck(:name).to_set
      files.reject { |name, _| ran.include?(name) }
        .sort_by { |name, _| [ name.split("/").last, name ] }
        .map { |name, path| read(name, path) }
    end

    def run(dry_run: false)
      results = []
      ActiveRecord::Base.transaction do
        pending.each do |migration|
          counts = migration.operations.map { |operation| Operations.apply(operation) }
          Records::ContentMigration.create!(name: migration.name, results: counts, ran_at: Time.current) unless dry_run
          results << Result.new(name: migration.name, counts:)
        end
        raise ActiveRecord::Rollback if dry_run
      end
      results
    end

    def files
      layers.flat_map do |layer, root|
        Dir.glob(root.join("migrations/*.yml").to_s).sort.map { |path| [ "#{layer}/#{File.basename(path, '.yml')}", Pathname(path) ] }
      end
    end

    def layers
      list = [ [ :core, Nibble.core_schema_path ] ]
      list << [ :theme, Nibble.config.theme_path.join("schema") ] if Nibble.config.theme_path
      list << [ :site, Nibble.config.site_schema_path ]
    end

    def read(name, path)
      data = YAML.safe_load_file(path) || {}
      operations = data.is_a?(Hash) ? Array(data["operations"]) : []
      raise Error, "#{path}: needs a list of operations" if operations.empty?

      operations.each_with_index { |operation, index| Operations.validate!(operation, "#{path}: operations.#{index}") }
      Migration.new(name:, path:, operations:)
    end
  end
end

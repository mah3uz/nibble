module Nibble
  class Upgrade
    Stopped = Class.new(Error)
    Result = Data.define(:migrations, :snapshot, :warnings)

    def self.run(**options) = new(**options).run

    def initialize(allow_data_loss: false, database: nil, log: ->(_line) { })
      @allow_data_loss = allow_data_loss
      @database = database || method(:prepare_database)
      @log = log
    end

    def run
      compatible!
      @log.call("database: running migrations")
      @database.call
      warnings = verify!("before content migrations")
      migrations = ContentMigrations.run
      Events.dispatch_pending
      warnings |= verify!("after content migrations")
      Result.new(migrations:, snapshot: Drift.record_snapshot!, warnings:)
    end

    private

    def compatible!
      theme = Nibble.config.active_theme or return
      return if theme.compatible_with_core?

      raise Stopped, "theme '#{theme.handle}' asks for nibble #{theme.manifest['nibble'].inspect}, " \
                     "and this release provides theme API #{THEME_API_VERSION}"
    end

    def verify!(moment)
      check = Check.run(allow_data_loss: @allow_data_loss)
      return check.warnings.map(&:to_s) if check.ok?

      raise Stopped, "#{moment}, nibble:check found:\n#{check.problems.map { |problem| "  ✗ #{problem}" }.join("\n")}"
    end

    def prepare_database
      require "rake"
      Rails.application.load_tasks unless Rake::Task.task_defined?("db:prepare")
      Rake::Task["db:prepare"].invoke
    end
  end
end

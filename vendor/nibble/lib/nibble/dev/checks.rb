module Nibble
  module Dev
    module Checks
      REPORTER = Nibble.core_root.join("lib/commands/minitest_json.rb")
      LINTERS = %w[ruby js types].freeze

      module_function

      def tools
        [
          Tool.new(name: "check", title: "Check the site", read_only: true, handler: method(:check), input: Dev.schema,
            description: "Schema, theme and roles problems, content the schema no longer covers, and Nibble files changed in " \
                         "place, each with where it is. Run it after changing schema YAML or a theme."),
          Tool.new(name: "run_tests", title: "Run tests", read_only: true, handler: method(:run_tests),
            description: "Run the site's tests and get the failures as data: test, file:line, message and backtrace. Passing tests aren't listed.",
            input: Dev.schema({ "paths" => { "type" => "array", "items" => { "type" => "string" }, "description" => "Files or folders; all tests if left out" },
                                "name" => { "type" => "string", "description" => "Only tests whose name matches" } })),
          Tool.new(name: "lint", title: "Lint", read_only: true, handler: method(:lint),
            description: "RuboCop (ruby), ESLint (js) or the Vue/TypeScript checker (types), as a list of findings with file and line.",
            input: Dev.schema({ "tool" => { "type" => "string", "enum" => LINTERS },
                                "paths" => { "type" => "array", "items" => { "type" => "string" } } }, %w[tool]))
        ]
      end

      def check(_input)
        report = Check.run
        findings = report.findings.map { |problem| { "level" => problem.level.to_s, "source" => problem.source, "message" => problem.message } }
        drift = begin
          Drift.issues.map { |issue| { "source" => issue.source, "message" => issue.message } }
        rescue ActiveRecord::ActiveRecordError => error
          [ { "source" => "database", "message" => error.message } ]
        end
        changed = Eject.unmanaged.map do |path|
          { "source" => path, "message" => "Nibble's file was changed in place, so the next upgrade refuses. Put it back, and eject it if the site must change it." }
        end
        { "ok" => report.ok? && drift.empty? && changed.empty?, "findings" => findings, "data_drift" => drift, "changed_nibble_files" => changed }
      end

      def run_tests(input)
        report = Rails.root.join("tmp/nibble-dev-tests-#{SecureRandom.hex(4)}.json")
        command = [ "bin/rails", "test", *Array(input["paths"]).map(&:to_s) ]
        command += [ "-n", "/#{input['name']}/" ] if input["name"].present?
        output, ok = Dev.run(*command, env: { "RAILS_ENV" => "test", "NIBBLE_TEST_REPORT" => report.to_s,
                                              "RUBYOPT" => [ ENV["RUBYOPT"], "-rbundler/setup", "-r#{REPORTER}" ].compact.join(" ") })
        result = report.file? ? JSON.parse(report.read) : { "error" => "the tests didn't finish", "output" => Dev.clip(output, 6_000) }
        result.merge("ok" => ok)
      ensure
        report&.delete if report&.file?
      end

      def lint(input)
        paths = Array(input["paths"]).map(&:to_s)
        case input["tool"]
        when "ruby" then rubocop(paths)
        when "js" then eslint(paths)
        when "types" then types
        else { "error" => "tool must be one of #{LINTERS.join(', ')}" }
        end
      end

      def rubocop(paths)
        output, ok = Dev.run("bin/rubocop", "--format", "json", *paths, timeout: 300)
        files = JSON.parse(output[/\{.*\}/m] || "{}")["files"].to_a
        findings = files.flat_map do |file|
          file["offenses"].map { |offense| { "file" => file["path"], "line" => offense.dig("location", "line"), "rule" => offense["cop_name"], "message" => offense["message"] } }
        end
        { "ok" => ok, "findings" => findings.first(200), "count" => findings.size }
      end

      def eslint(paths)
        output, ok = Dev.run("npx", "eslint", "--format", "json", *(paths.presence || [ "." ]), timeout: 300)
        findings = JSON.parse(output[/\[.*\]/m] || "[]").flat_map do |file|
          file["messages"].map { |message| { "file" => Dev.relative(file["filePath"]), "line" => message["line"], "rule" => message["ruleId"], "message" => message["message"] } }
        end
        { "ok" => ok, "findings" => findings.first(200), "count" => findings.size }
      end

      def types
        output, ok = Dev.run("npx", "vue-tsc", "-p", "tsconfig.app.json", "--noEmit", "--pretty", "false", timeout: 600)
        findings = output.lines.filter_map do |line|
          file, row, message = line.match(/\A(.+?)\((\d+),\d+\): (.+)\z/)&.captures
          file && { "file" => file, "line" => row.to_i, "message" => message.strip }
        end
        { "ok" => ok, "findings" => findings.first(200), "count" => findings.size }
      end
    end
  end
end

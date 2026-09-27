require "json"
require "minitest"

# Required after bundler/setup by the developer tools' run_tests: failures as data for an agent, written to NIBBLE_TEST_REPORT.
module NibbleMinitestJson
  class Reporter < Minitest::AbstractReporter
    def initialize(path)
      super()
      @path = path
      @counts = Hash.new(0)
      @failures = []
    end

    def record(result)
      @counts["tests"] += 1
      @counts["assertions"] += result.assertions
      return @counts["skips"] += 1 if result.skipped?
      return if result.passed?

      @counts[result.error? ? "errors" : "failures"] += 1
      failure = result.failure
      trace = Minitest.backtrace_filter.filter(Array(failure.backtrace)).map { |frame| local(frame) }
      @failures << { "test" => "#{result.klass}##{result.name}", "at" => local(failure.location), "kind" => result.error? ? "error" : "failure",
                     "message" => failure.message.to_s[0, 2_000], "backtrace" => trace.first(10) }
    end

    def local(frame) = frame.to_s.delete_prefix("#{Dir.pwd}/")

    def report
      File.write(@path, JSON.generate("counts" => @counts, "seed" => Minitest.seed, "failures" => @failures.first(100)))
    end
  end

  def self.minitest_plugin_init(_options)
    Minitest.reporter << Reporter.new(ENV["NIBBLE_TEST_REPORT"]) if ENV["NIBBLE_TEST_REPORT"]
  end
end

Minitest.register_plugin(NibbleMinitestJson)

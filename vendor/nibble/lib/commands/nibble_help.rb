require "open3"
require "pathname"
require "rails/version"
require "yaml"

# What bin/rails nibble prints: the release, the site's record of it, what it runs on, then every command. Read from
# files with nothing booted, so it still answers when the site won't boot.
module NibbleHelp
  CORE = Pathname(__dir__).join("../..").expand_path
  # Thor's own, which every namespace repeats.
  GENERIC = %w[help tree].freeze

  module_function

  def root = defined?(APP_PATH) ? Pathname(APP_PATH).dirname.parent : Rails.root

  def constant(name) = CORE.join("lib/nibble.rb").read[/^\s*#{name} = "?([\w.]+)/, 1]

  def running = constant("VERSION")

  def settings = root.join("config/nibble.yml").then { |file| file.file? ? file.read : "" }

  def recorded = YAML.safe_load(settings.partition("# Written by Nibble").last.lines.drop(1).join).to_h["install"]

  def print(shell)
    header(shell)
    commands(shell)
  end

  def header(shell)
    install = recorded
    site = if install.nil? then "no install record"
    elsif install["version"] != running then "records #{install['version']}: an upgrade to #{running} didn't finish"
    else "on #{install['version']} since #{install['at']}"
    end
    theme = ENV["NIBBLE_THEME"].to_s.strip.then { |named| named.empty? ? settings[/^\s*theme:\s*["']?([a-z0-9_-]+)/, 1] || "crumbs" : named }
    # load_defaults: behaviour a release changes stays off until the site raises this to that release.
    defaults = settings[/^\s*load_defaults:\s*["']?([\d.]+)/, 1] || "0.0"
    behaviour = if Gem::Version.new(defaults) >= Gem::Version.new(running) then "as of #{defaults} (load_defaults)"
    else "as of #{defaults} — #{running}'s changes stay off until load_defaults is raised"
    end
    node = (Open3.capture2("node", "--version").first.strip.delete_prefix("v") rescue "").then { |v| v.empty? ? "missing" : v }

    box(shell, "Nibble #{running}", {
      "Site" => site,
      "Theme" => theme,
      "Behaviour" => behaviour,
      "Runs on" => "Ruby #{RUBY_VERSION} · Rails #{Rails::VERSION::STRING} · Node #{node}",
      "Contracts" => "theme API #{constant('THEME_API_VERSION')} · schema format #{constant('SCHEMA_FORMAT')} · " \
                     "content format #{constant('CONTENT_FORMAT_VERSION')}"
    })
  end

  # Widths are measured before colouring, which a terminal draws but doesn't count.
  def box(shell, title, rows)
    label = rows.keys.map(&:length).max
    lines = rows.map { |name, value| [ name.ljust(label), value ] }
    inner = [ lines.map { |name, value| name.length + 2 + value.length }.max, title.length + 2 ].max

    shell.say "╭─ #{shell.set_color(title, :green, :bold)} #{'─' * (inner - title.length - 1)}╮"
    lines.each do |name, value|
      shell.say "│ #{shell.set_color(name, :cyan)}  #{value}#{' ' * (inner - name.length - 2 - value.length)} │"
    end
    shell.say "╰#{'─' * (inner + 2)}╯"
  end

  def commands(shell)
    Dir[CORE.join("lib/commands/nibble/*_command.rb").to_s].sort.each { |file| require file }
    groups = Rails::Command::Base.subclasses.select { |klass| klass.namespace.to_s.match?(/\Anibble(:|\z)/) }
      .sort_by { |klass| klass.namespace == "nibble" ? "" : klass.namespace }
      .to_h { |klass| [ klass.namespace, listed(klass) ] }
      .reject { |_, rows| rows.empty? }
    width = groups.values.flatten(1).map { |usage, _| usage.length }.max

    groups.each do |namespace, rows|
      shell.say ""
      shell.say namespace == "nibble" ? "Commands" : namespace.delete_prefix("nibble:").capitalize, :cyan
      rows.each { |usage, description| shell.say "  #{usage.ljust(width)}  #{description}" }
    end
    shell.say ""
    shell.say "bin/rails nibble:help COMMAND shows one command's options."
  end

  def listed(klass)
    klass.printable_commands
      .reject { |usage, _| GENERIC.include?(usage.split[1].to_s.split(":").last) }
      .map { |usage, description| [ usage, description.to_s.delete_prefix("# ") ] }
  end
end

# Rails dispatches commands past Thor's own error handling, so a bad option would otherwise print a backtrace.
module CleanFailures
  def exit_on_failure? = true

  def perform(command, args, config)
    super
  rescue *CleanFailures.handled => e
    warn e.message
    exit 1
  end

  # Nibble isn't loaded until a command boots the application, and a command may refuse before that.
  def self.handled = [ Thor::Error, (Nibble::Error if defined?(Nibble::Error)) ].compact
end

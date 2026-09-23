# Rails dispatches commands past Thor's own error handling, so a bad option would otherwise print a backtrace.
module CleanFailures
  def exit_on_failure? = true

  def perform(command, args, config)
    super
  rescue Thor::Error, Nibble::Error => e
    warn e.message
    exit 1
  end
end

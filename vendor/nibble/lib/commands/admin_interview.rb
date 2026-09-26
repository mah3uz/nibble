# Asking for an administrator, shared by the installer and nibble:admin:create.
module AdminInterview
  def build_admin(role: superuser_role)
    loop do
      name = ask_until("  Your name", :cyan) { |value| "a name is required" if value.blank? }
      email = ask_until("  Your email address", :cyan) { |value| "#{value.inspect} is not an email address" unless value.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/) }
      password = ask_password
      user = Nibble::User.new(name:, email_address: email.strip.downcase, password:, roles: [ role ])
      return user if user.save

      say "  #{user.errors.full_messages.to_sentence}", :red
    end
  end

  # The install never asks: the first user has to be able to do everything.
  def superuser_role = Nibble::Role.find_by(superuser: true) || Nibble::Role.find_by!(handle: "admin")

  def ask_role
    roles = Nibble::Role.order(:id).to_a
    return superuser_role if roles.one?

    roles.each.with_index(1) { |role, number| say "  #{number}. #{role.title}#{' — full access' if role.superuser?}", :white }
    chosen = ask_until("  Which role", :cyan) do |value|
      "pick a number between 1 and #{roles.size}" unless value.match?(/\A\d+\z/) && (1..roles.size).cover?(value.to_i)
    end
    roles[chosen.to_i - 1]
  end

  def ask_password
    say "  At least #{Nibble::User::MINIMUM_PASSWORD_LENGTH} characters, with #{Nibble::User::PASSWORD_RULES.keys.to_sentence}.", :white
    loop do
      password = ask_secret("  A password")
      problems = Nibble::User.password_problems(password)
      next problems.each { |problem| say "  That password #{problem}", :red } if problems.any?
      return password if !$stdin.tty? || ask_secret("  Type it again") == password

      say "  They do not match", :red
    end
  end

  # Thor's echo: false blocks when stdin is a pipe, which would hang a scripted run.
  def ask_secret(prompt)
    answer = $stdin.tty? ? ask(prompt, :cyan, echo: false).tap { say "" } : ask(prompt, :cyan)
    no_input! if answer.nil?
    answer
  end

  # Thor returns nil at end of input; without this a scripted run would spin on the same prompt forever.
  def ask_until(prompt, colour)
    loop do
      answer = ask(prompt, colour)
      no_input! if answer.nil?

      value = answer.to_s.strip
      problem = yield(value) or return value

      say "  #{problem}", :red
    end
  end

  def no_input! = abort("  stopped: no more input. Run this in a terminal to answer the questions.")
end

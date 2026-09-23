require_relative "../clean_failures"
require_relative "../admin_interview"

class NibbleAdminCommand < Rails::Command::Base
  extend CleanFailures
  include AdminInterview
  namespace "nibble:admin"

  desc "create", "Add a user, asking for their name, email address, password and role"
  def create
    boot_application!
    Role.seed_defaults!
    role = ask_role
    user = build_admin(role:)
    say_status :create, "#{role.title.downcase} #{user.email_address}", :green
  end
end

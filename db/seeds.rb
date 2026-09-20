Role.seed_defaults!

admin_email = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]

if admin_email.blank? || admin_password.blank?
  # Warn rather than abort: db:prepare seeds a new container's database on first boot.
  unless User.administrators.exists?
    warn "No admin user yet. Create one with: ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed " \
         "(on a server: bin/kamal app exec -e ADMIN_EMAIL=... -e ADMIN_PASSWORD=... 'bin/rails db:seed')"
  end
else
  User.find_or_create_by!(email_address: admin_email.strip.downcase) do |user|
    user.name = ENV.fetch("ADMIN_NAME", "Administrator")
    user.password = admin_password
    user.roles = [ Role.find_by!(handle: "admin") ]
  end
end

Nibble::Role.seed_defaults!

# Warn rather than abort: db:prepare seeds a new container's database on first boot.
unless Nibble::User.administrators.exists?
  warn "No admin user yet. Create one with: bin/rails nibble:admin:create " \
       "(on a server: bin/kamal app exec -i 'bin/rails nibble:admin:create')"
end

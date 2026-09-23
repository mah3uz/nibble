# Every check Nibble runs on itself. Run it with bin/ci.

# Nibble's checks run against this repository's own settings, whichever theme a shell exports for nibble.ink.
ENV.delete("NIBBLE_THEME")

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Content: nibble:build", "bin/rails nibble:build"
  # Against the test database: the development one holds whatever content a contributor works on.
  step "Schema: nibble:check", "env RAILS_ENV=test bin/rails nibble:check"
  step "Style: Vue/TypeScript lint", "npm run lint"
  step "Style: Prettier", "npm run format:check"
  step "Types: vue-tsc", "npm run check"
  step "Tests: frontend unit", "npm run test:js"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Build: client + SSR bundles", "env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/vite build && env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/vite build --ssr"
  step "Tests: SSR smoke", "bin/ssr-smoke"
  step "Tests: install and upgrade", "bin/release-smoke"

  # Build test assets up front so no test triggers (and races) an on-demand Vite build.
  step "Build: test assets", "env RAILS_ENV=test bin/vite build"
  step "Tests: Rails", "bin/rails test"
  # This repository's site/ is nibble.ink's own, in a private repository of its own; a clone has none.
  step "Tests: nibble.ink", "bin/rails test site/test" if Dir.glob("site/test/**/*_test.rb").any?

  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end

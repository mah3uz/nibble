# Every check Nibble runs on itself. Run it with bin/ci.

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Schema: nibble:check", "bin/rails nibble:check"
  step "Style: Vue/TypeScript lint", "npm run lint"
  step "Style: Prettier", "npm run format:check"
  step "Types: vue-tsc", "npm run check"
  step "Tests: frontend unit", "npm run test:js"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Build: client + SSR bundles", "env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/vite build && env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/vite build --ssr"
  step "Tests: SSR smoke", "bin/ssr-smoke"

  # Build test assets up front so no test triggers (and races) an on-demand Vite build.
  step "Build: test assets", "env RAILS_ENV=test bin/vite build"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end

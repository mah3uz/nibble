---
title: Tests and checks
description: bin/ci, what it runs, and the end-to-end suite.
order: 3
---

# Tests and checks

```sh
bin/ci
```

One command, and the only definition of Nibble's checks. It runs, in order: `bin/setup`, RuboCop,
`nibble:check`, ESLint, Prettier, `vue-tsc`, the frontend unit tests, bundler-audit, Brakeman, the client and SSR
builds, an SSR smoke test, the test-asset build, the Rails tests, a site's own tests if it has any, and the seeds.

Individually:

```sh
bin/rails test        # build test assets first if Vite has not: RAILS_ENV=test bin/vite build
npm run lint          # ESLint
npm run format:check  # Prettier
npm run check         # vue-tsc
npm run test:js       # frontend unit tests
bin/rubocop
bin/ssr-smoke         # renders every page through a freshly built SSR bundle
```

## Writing tests

Tests encode **why** behaviour matters, not just what it does. A test that cannot fail when the business rule
changes is not doing anything. The suite is Minitest, run in parallel, with fixtures.

## The SSR smoke test

`bin/ssr-smoke` starts the built SSR bundle and renders every page component with only the shared props, checking
the process survives. A component that touches browser globals on import would otherwise take down server
rendering for the whole public site, and nothing else would catch it.

It refuses to run when something is already listening on port 13714, so a stale process cannot make it pass
against the wrong bundle, and it checks the port is free again before it exits.

That port is fixed by `@inertiajs/vite`, so only one server can hold it. **Usually that is `bin/dev`**: Puma's
`inertia_ssr` plugin starts an SSR server unless the Vite dev server is already running, and at boot it often is
not — which is also why `bin/dev` sometimes logs `Inertia SSR: process exited … restarting in 1s`, the plugin
losing a race for the port. Stop `bin/dev` before running the smoke test, or `bin/ci`.

## End-to-end

The Playwright suite drives the control panel in a browser. It is separate from `bin/ci` because it needs a built
application and a database of its own.

## A site's tests

A site puts its own in `site/test/`, which `bin/ci` runs after Nibble's. Nibble's own stay in `test/`, which is
ours — a site putting tests there would meet them again at the next upgrade.

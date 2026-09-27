---
id: contributing-testing
title: Tests and checks
description: bin/ci and everything it runs, writing tests that encode why, the server-rendering smoke test, the
  browser suite and the playground.
order: 3
---

# Tests and checks

After reading this guide, you will know:

- What `bin/ci` runs, and what a failure usually means.
- How to write a test Nibble will take.
- How the server-rendering smoke test works, and how to run a second instance beside `bin/dev`.
- How to run the browser suite and use the playground.

## 1. bin/ci

```sh
bin/ci
```

One command, and the only definition of Nibble's checks. It is the same suite a release refuses to go out without.
In order:

1. `bin/setup`
2. RuboCop
3. `nibble:build` — content files and the schema, without a database
4. `nibble:check`
5. ESLint, Prettier and `vue-tsc`
6. the frontend unit tests
7. bundler-audit and Brakeman
8. the client and server-rendering builds, then the SSR smoke test
9. the install and upgrade test — a release archive built from this checkout, installed, then upgraded
10. the Rails tests
11. nibble.ink's tests in `site/test/`, when this checkout has nibble.ink's `site/`
12. the seeds

It prints each step and stops at the first failure, naming it:

| Failing step | Usually means |
|---|---|
| `Content: nibble:build` | a file in `site/content/` has no `id`, bad frontmatter or a field the blueprint lacks |
| `Schema: nibble:check` | a schema error, stranded content, or generated types out of date |
| `Types: vue-tsc` | a view uses a field its blueprint does not have |
| `Tests: SSR smoke` | a component touches a browser global while being imported |
| `Security: Brakeman` | a new warning — fix it, or record why it is safe in `config/brakeman.ignore` |

Individually:

```sh
bin/rails test          # build test assets first if Vite has not: RAILS_ENV=test bin/vite build
npm run lint            # ESLint
npm run format:check    # Prettier
npm run check           # vue-tsc
npm run test:js         # frontend unit tests
bin/rubocop
bin/ssr-smoke
```

> [!NOTE]
> The tests ignore `NIBBLE_THEME` and use the theme `config/nibble.yml` names, so a theme exported in your shell for
> `bin/dev` never changes what they see.

## 2. Writing tests

**Tests encode why a behaviour matters, not only what it does.** A test that cannot fail when the rule changes is not
doing anything, and it costs as much to maintain as a good one.

So the name states the rule — "a page whose file has gone is gone" — and the assertion's message says what breaks for
a site if it fails.

The suite is Minitest, runs in parallel and uses fixtures:

| Kind | Where | For |
|---|---|---|
| Unit | `test/lib/` | the engine's own behaviour |
| Controller and integration | `test/controllers/`, `test/integration/` | a whole request: routing, rendering, caching |
| Architecture | `test/architecture/` | rules a reviewer would otherwise have to remember — database portability, the SSR port agreeing at both ends |

Nibble's tests live in this repository's `test/` and never ship in a release. A site's `test/` is its own, and
`bin/rails test` runs it.

## 3. The SSR smoke test

`bin/ssr-smoke` starts the built server-rendering bundle and renders every page component with only the shared props,
checking the process survives. A component that touches a browser global on import would otherwise take down server
rendering for the whole public site, and nothing else would notice.

It picks a free port of its own, so it runs while `bin/dev` is up.

> [!NOTE]
> Both ends of server rendering read `INERTIA_SSR_PORT` — `vendor/nibble/frontend/ssr/ssr.ts` and
> `config/initializers/inertia_rails.rb` — and default to 13714. Give a second instance a port of its own, or the two
> fight over 13714:
>
> ```sh
> INERTIA_SSR_PORT=13715 RAILS_ENV=test bin/rails s -p 3300
> ```

## 4. The browser suite

The Playwright suite drives the Control Plane and the public site in a real browser. It is not part of `bin/ci`,
because it needs a running application and a database of its own. Run it before a release, and after any change to
the Control Plane you would struggle to test otherwise.

Once:

```sh
cd test/e2e && npm install && npx playwright install chromium
```

Then, against a running dev server:

```sh
node test/e2e/cp-e2e.mjs http://localhost:3100 EMAIL PASSWORD_FILE
node test/e2e/crumbs-e2e.mjs http://localhost:3100
node test/e2e/nibble-playground-e2e.mjs http://localhost:3100 EMAIL PASSWORD_FILE
node test/e2e/cp-screenshots.mjs http://localhost:3100 EMAIL PASSWORD_FILE
```

| Script | Does |
|---|---|
| `cp-e2e.mjs` | signs in, writes and publishes content, and audits every screen for accessibility |
| `crumbs-e2e.mjs` | every public page: hydration, console errors and the same audit |
| `nibble-playground-e2e.mjs` | every blueprint and fieldtype, rendered |
| `cp-screenshots.mjs` | a screenshot of every Control Plane screen, for reviewing a redesign |

The password is read from a file, so it stays out of your shell history. Both browser suites run axe and fail on
serious or critical violations.

## 5. The playground

`/cp/nibble/playground`, in development only, renders every blueprint in the site plus one using every fieldtype,
backed by records in memory. It is the fastest way to check a fieldtype you are writing, or a change to the editor,
against every shape at once — without creating a single entry.

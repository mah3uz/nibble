# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Rule 0 — No Code comments

Default to writing no comments. Comments explain WHY (non-obvious constraints or workarounds), never WHAT.
Never write multi-line comment blocks or restate what the code makes obvious.
No reference to tickets, plans, or external sources. No narrative comments.
Never mention a plan, a plan file, or a plan's phases or task numbers in code comments or git commit messages.

## Rule 1 — Think Before Coding

State assumptions explicitly. If uncertain, ask rather than guess.
Present multiple interpretations when ambiguity exists.
Push back when a simpler approach exists.
Stop when confused. Name what's unclear.

## Rule 2 — Simplicity First

Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
Test: would a senior engineer say this is overcomplicated? If yes, simplify.

## Rule 3 — Surgical Changes

Touch only what you must. Clean up only your own mess.
Don't "improve" adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.

## Rule 4 — Goal-Driven Execution

Define success criteria. Loop until verified.
Don't follow steps. Define success and iterate.
Strong success criteria let you loop independently.

## Rule 5 — Use the model only for judgment calls

Use me for: classification, drafting, summarization, extraction.
Do NOT use me for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory

Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them

If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.
Don't blend conflicting patterns.

## Rule 8 — Read before you write

Before adding code, read exports, immediate callers, shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Rule 9 — Tests verify intent, not just behavior

Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step

Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.
If you lose track, stop and restate.

## Rule 11 — Match the codebase's conventions, even if you disagree

Conformance > taste inside the codebase.
If you genuinely think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud

"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

## Project status

Nibble is a standalone CMS. A Rails 8 app serves a themed public site and a control panel, both Inertia + Vue 3
with SSR, on SQLite. Content is schema-driven: YAML declares collections, taxonomies,
blueprints, globals, navigation and forms, read in three layers — Nibble's, the theme's, then the site's — and
entries and terms are rows whose `data` is validated against a blueprint.

Nibble is installed by `install.sh`, which unpacks a release archive into `vendor/nibble`, and
`bin/rails nibble:upgrade` replaces that folder with the next release. See `README.md` for
setup, commands, what a site owns, and upgrading.

It is a product in its own right, not a copy of another site. Design features on their own merits.

## Stack (locked; do not re-litigate)

Rails 8 · Inertia Rails + Vue 3 with SSR (Vite, Node SSR process on port 13714) · SQLite (WAL) for all data plus
Solid Queue/Cache · Tiptap (`@tiptap/vue-3`, free extensions only) for rich text · schema-driven fieldtypes for
everything else · Active Storage on S3 behind a CDN, served through `AssetFilesController` transforms · shadcn-vue
control panel · themes as npm workspaces under `site/themes/*` and `vendor/nibble/themes/*` · Kamal on a VPS · nightly `VACUUM INTO` snapshots to S3
(`DatabaseSnapshotJob`). Do not introduce React or Hotwire.

## Architecture

**Where things live. Everything under `vendor/nibble/` is ours; everything else is the site's.** The site's `Gemfile`
evaluates `vendor/nibble/Gemfile`, which loads `Nibble::Engine`; `config/application.rb` is plain Rails.
- `vendor/nibble/lib/nibble/` — the engine, autoloaded as `Nibble::`: `Schema`, `Field`/`Fields`/`Fieldtype`, `Records::*`,
  `Lifecycle`, `Query`, `Presenter`, `Routing`, `PageProps`, `PageCache`, `Search`, `Seo`, `Sitemaps`, `Assets`,
  `Forms`, `Outbound`, `Webhooks`, `Access`, `Packages`, `ContentMigrations`, `Release`, `Releases`, `Eject`,
  `Install`, `Prepare`, `Check`.
- `vendor/nibble/app/` — laid out as Rails lays out `app/`, and added the same way, so names are unchanged:
  `controllers/` (`SiteController` catch-all, `Admin::*`, `Api::V1::*`, `FormsController`, `SitemapsController`,
  `AssetFilesController`), `models/` (only identity and access: users, roles, sessions, credentials, API tokens),
  `jobs/`, `mailers/`, `services/`, `helpers/`, `channels/`, `views/`.
- `vendor/nibble/frontend/` — `nibble-admin/` (the control panel, `@nibble-admin`, also `@` and `~`), `nibble/` (the
  theme runtime, `@nibble`), `entrypoints/`, `ssr/`. It is Vite's `sourceCodeDir`.
- `vendor/nibble/core_schema/` — the baseline schema YAML. Schema is read in three layers: this, then the theme's
  `schema/`, then the site's own `site/schema/`, and the last to define a handle wins.
- Everything outside `vendor/nibble/` — `app/`, `config/`, `db/migrate`, `test/`, `site/`, the `Gemfile` — is **a site's,
  not ours.** Nibble renders it from `vendor/nibble/templates/` at install and never writes it again; Rails' own
  `config/initializers/` and `test/` serve a site's Ruby and tests. A site's own `app/` loads beside ours and its views
  are looked in first. Under `site/`: `schema/`, `content/` (content kept as files — the only place a collection's
  `files` can name), `themes/<its own>/`, `cp/pages/<same path as ours>.vue` replacing a control panel screen and
  `cp/slots/*.vue` replacing chrome; `site/types.d.ts` is generated from the schema and imported as `@site/types`.
  `bin/rails nibble:eject <path>` is how a site takes one of our files over, recorded in `config/nibble.yml`.
- Themes: `site/themes/<theme>/` is looked in first, then `vendor/nibble/themes/<theme>/`, where `crumbs` ships.
  Each has `layouts/`, `views/` (each `.vue` may have a `.yml` query sidecar), `views/sets/`,
  `components/`, `styles/`, `schema/`; **a theme never ships content**; `@theme` resolves to the active one,
  named in `config/nibble.yml`, then `NIBBLE_THEME`, defaulting to `crumbs`. `nibble:generate:theme` starts one.
- This repository's root is also nibble.ink. Its `site/` isn't tracked here, so a clone has none; nibble.ink's holds
  the `bite` theme (with `default_content/` to import on a fresh start), the schema, and the documentation in
  `site/content/docs`. The tracked settings name `crumbs`, so a clone works without it; nibble.ink runs with
  `NIBBLE_THEME=bite`. `bin/rails test site/test` checks its content, and `bin/ci` runs that when `site/` is present.

**Public request flow:**
1. `NibbleRedirectsMiddleware`, backed by the `redirects` table and cached.
2. Fixed routes: `/media/:uuid/…`, `POST /forms/:handle`, `/robots.txt`, `/sitemap.xml`, `/sitemap-:handle.xml`.
3. The catch-all `SiteController#show` calls `Nibble::Routing.resolve`, which returns an entry, term, redirect or nothing.
4. `Nibble::PageProps` runs the view's query sidecar through `Nibble::Query` and the `Nibble::Presenter`.
5. Inertia SSR renders `theme/<view>` from the active theme.
6. `Nibble::PageCache` stores the response against the tags `Nibble::Dependencies` collected, echoed as `Surrogate-Key`.

**Content model:** entries, terms, globals and navigation are rows; their fields live in a `data` JSON column
validated against a blueprint built from the schema. `Nibble::Lifecycle` owns drafts, revisions, scheduling,
workflow, trash and publishing. `Nibble::Uris` keeps URIs current and records a 301 when a live record's URI changes.
`Nibble::Events` publishes through an outbox; the subscribers registered in `Nibble.boot!` update relations, URIs,
the audit log, notifications, the page cache, the search index and webhooks.

**Invariants:**
- **Database portability:** no SQLite-specific SQL outside `Nibble::Search`, which wraps FTS5. Use the Rails `json`
  type for JSON columns and never raw `json_extract` in app code.
- **Rich-text safety:** themes output rich text as HTML, so it is rendered server-side from Tiptap JSON by
  `RichText::Renderer` and must pass `RichText::Sanitizer`'s allowlist; uploaded SVGs pass
  `Nibble::Assets::SvgSanitizer`. Tests must prove `script`, `on*` attributes and `javascript:` URLs are stripped.
- **Redirects are single-hop:** chains are repointed on save.
- **Content import:** package import and content migrations are idempotent and safely re-runnable.
- **Versioned contracts:** `Nibble::SCHEMA_FORMAT`, `THEME_API_VERSION` and `CONTENT_FORMAT_VERSION` in `vendor/nibble/lib/nibble.rb`
  change only with a migration or upgrade path.

## File searching and grep
For any file search or grep in the current git-indexed directory, use fff tools.

## Git & Version Control

- **NEVER add to message**. Do not add or mention co-authors by Anthropic or any other AI in commit messages. Keep commit messages clean and focused on the code changes.

## Commands

See `README.md` for setup, running the dev server, tests/checks (`bin/ci`), seed content and
deployment commands.

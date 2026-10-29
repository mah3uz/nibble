# CLAUDE.md

Apply Global to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Project status

Nibble is a standalone CMS. A Rails 8 app serves a themed public site and a Control Plane, both Inertia + Vue 3
with SSR, on SQLite. Content is schema-driven: YAML declares collections, taxonomies,
blueprints, globals, navigation and forms, read in three layers — Nibble's, the theme's, then the site's — and
entries and terms are rows whose `data` is validated against a blueprint.

Nibble is installed by `nibble new` (the CLI; `install.sh` fetches it first), which unpacks a release archive into
`vendor/nibble`, and
`bin/rails nibble:upgrade` replaces that folder with the next release. See `README.md` for
setup, commands, what a site owns, and upgrading.

It is a product in its own right, not a copy of another site. Design features on their own merits.

## Stack (locked; do not re-litigate)

Rails 8 · Inertia Rails + Vue 3 with SSR (Vite, Node SSR process on port 13714) · SQLite (WAL) for all data plus
Solid Queue/Cache · Tiptap (`@tiptap/vue-3`, free extensions only) for rich text · schema-driven fieldtypes for
everything else · Active Storage on S3 behind a CDN, served through `AssetFilesController` transforms · shadcn-vue
Control Plane · themes as npm workspaces under `site/themes/*` and `vendor/nibble/themes/*` · Kamal on a VPS · nightly `VACUUM INTO` snapshots to S3
(`DatabaseSnapshotJob`). Do not introduce React or Hotwire.

shadcn-vue isn't a dependency: add a Control Plane component with `npx shadcn-vue@latest add <component>`
(`components.json` at the root), and copy any stylesheet variant it needs from shadcn-vue's `tailwind.css` into
`vendor/nibble/frontend/entrypoints/cp.css`, as `data-open:` and `no-scrollbar` are. See `docs/contributing/architecture.md` §5.

## Architecture

**Where things live. Everything under `vendor/nibble/` is ours; everything else is the site's.** The site's `Gemfile`
evaluates `vendor/nibble/Gemfile`, which loads `Nibble::Engine`; `config/application.rb` is plain Rails.
- `vendor/nibble/lib/nibble/` — the engine, autoloaded as `Nibble::`: `Schema`, `Field`/`Fields`/`Fieldtype`, `Records::*`,
  `Lifecycle`, `Query`, `Presenter`, `Routing`, `PageProps`, `PageCache`, `Search`, `Seo`, `Sitemaps`, `Assets`,
  `Forms`, `Outbound`, `Webhooks`, `Access`, `Packages`, `ContentMigrations`, `Release`, `Releases`, `Eject`,
  `Install`, `Prepare`, `Check`, and for agents `Principal`, `Policy`, `AgentAccess`, `Oauth`, `Operations`,
  `AgentGuide`, `Skills`, `Dev`.
- `vendor/nibble/app/` — laid out as Rails lays out `app/`, and added the same way, so names are unchanged:
  `controllers/` (`SiteController` catch-all, `Nibble::Cp::*`, `Api::V1::*` (read-only content API),
  `Api::V1::OperationsController` (management API), `Nibble::McpController`, `Nibble::Oauth::*`, `FormsController`,
  `SitemapsController`, `AssetFilesController`), `models/` (only identity and access: users, roles, sessions,
  credentials, API tokens, grants, OAuth clients/codes/tokens, device codes, approvals),
  `jobs/`, `mailers/`, `services/`, `helpers/`, `views/`.
- `vendor/nibble/frontend/` — `nibble-cp/` (the Control Plane, `@nibble-cp`, also `@` and `~`), `nibble/` (the
  theme runtime, `@nibble`), `entrypoints/`, `ssr/`. It is Vite's `sourceCodeDir`.
- `vendor/nibble/core_schema/` — the baseline schema YAML. Schema is read in three layers: this, then the theme's
  `schema/`, then the site's own `site/schema/`, and the last to define a handle wins.
- Everything outside `vendor/nibble/` — `app/`, `config/`, `db/migrate`, `test/`, `site/`, the `Gemfile` — is **a site's,
  not ours.** Nibble renders it from `vendor/nibble/templates/` at install and never writes it again; Rails' own
  `config/initializers/` and `test/` serve a site's Ruby and tests. A site's own `app/` loads beside ours and its views
  are looked in first. Under `site/`: `schema/`, `content/` (content kept as files — the only place a collection's
  `files` can name), `themes/<its own>/`, `cp/pages/<same path as ours>.vue` replacing a Control Plane screen and
  `cp/slots/*.vue` replacing chrome; `site/types.d.ts` is generated from the schema and imported as `@site/types`.
  `bin/rails nibble:eject <path>` is how a site takes one of our files over, recorded in `config/nibble.yml`.
- Themes: `site/themes/<theme>/` is looked in first, then `vendor/nibble/themes/<theme>/`, where `crumbs` ships.
  Each has `layouts/`, `views/` (each `.vue` may have a `.yml` query sidecar), `views/sets/`,
  `components/`, `styles/`, `schema/`; **a theme never ships content**; `@theme` resolves to the active one,
  named in `config/nibble.yml`, then `NIBBLE_THEME`, defaulting to `crumbs`. `nibble:generate:theme` starts one.
- This repository's root is also nibble.ink. Its `site/` isn't tracked here, so a clone has none; nibble.ink's holds
  the `bite` theme, `packages/default/` to import on a fresh start and the schema; its `content/docs` is a symlink to
  `vendor/nibble/docs`, where the documentation lives and ships with each release. The tracked settings name
  `crumbs`, so a clone works without it; nibble.ink runs with `NIBBLE_THEME=bite`. `bin/rails test site/test` checks
  its content, and `bin/ci` runs that when `site/` is present.
- `cli/` is the `nibble` command-line tool (Rust), in its own repository (`mah3uz/nibble-cli`) and not tracked here;
  its own CI tests it against a Nibble checkout. `bin/ci` checks only Nibble.

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
- **One permission check for every change:** `Nibble::Lifecycle.call` requires an `actor:` (a user, a
  `Nibble::Principal` carrying a connected app's grant, or `Nibble::Principal.system`) and asks `Nibble::Policy` before
  it runs, whoever calls it. An app's permission is the person's roles ∩ its grant ∩ the site's Agent access settings.
  The management API (`/api/v1/operations`) and MCP (`/mcp`) are generated from `Nibble::Operations`; nothing hand-mirrors it.
- **Links are safe:** navigation URLs, link fields and agent-written Markdown accept only web, email, phone and on-site
  links (`Nibble::SafeUrl`).
- **Redirects are single-hop:** chains are repointed on save.
- **Content import:** package import and content migrations are idempotent and safely re-runnable.
- **Versioned contracts:** `Nibble::SCHEMA_FORMAT`, `THEME_API_VERSION`, `CONTENT_FORMAT_VERSION` and
  `MANAGEMENT_API_VERSION` in `vendor/nibble/lib/nibble.rb` change only with a migration or upgrade path.

## File searching and grep
For any file search or grep in the current git-indexed directory, use fff tools.

## Git & Version Control

- **NEVER add to message**. Do not add or mention co-authors by Anthropic or any other AI in commit messages. Keep commit messages clean and focused on the code changes.

## Commands

See `README.md` for setup, running the dev server, tests/checks (`bin/ci`), seed content and
deployment commands.

# Nibble

How this CMS is put together: where its code lives, how a request becomes a page, what a site owns, and the
rules the codebase holds itself to. Written for whoever — or whatever — needs to understand Nibble before
changing a site built with it.

This file is Nibble's and arrives with each release. A site's own conventions belong in its `CLAUDE.md`, and its own architecture notes in whatever file it
likes — this name is taken so that one is not.

## Project status

Nibble is a standalone CMS. A Rails 8 app serves a themed public site and a control panel, both Inertia + Vue 3
with SSR, on SQLite. Content is schema-driven: YAML declares collections, taxonomies,
blueprints, globals, navigation and forms, read in three layers — Nibble's, the theme's, then the site's — and
entries and terms are rows whose `data` is validated against a blueprint.

Nibble is installed by cloning it and running `install.sh`; releases are tags a site merges. See `README.md` for
setup, commands, what a site owns, and upgrading.

It is a product in its own right, not a copy of another site. Design features on their own merits:
there is no parity baseline to match, and no deviations to log.

## Stack (locked; do not re-litigate)

Rails 8 · Inertia Rails + Vue 3 with SSR (Vite, Node SSR process on port 13714) · SQLite (WAL) for all data plus
Solid Queue/Cache · Tiptap (`@tiptap/vue-3`, free extensions only) for rich text · schema-driven fieldtypes for
everything else · Active Storage on S3 behind a CDN, served through `AssetFilesController` transforms · shadcn-vue
control panel · themes as npm workspaces under `themes/*` · Kamal on a VPS · nightly `VACUUM INTO` snapshots to S3
(`DatabaseSnapshotJob`). Do not introduce React or Hotwire.

## Architecture

**Where things live. Everything under `lib/nibble/` is ours; everything else is the site's.**
- `lib/nibble/` — the engine, autoloaded as `Nibble::`: `Schema`, `Field`/`Fields`/`Fieldtype`, `Records::*`,
  `Lifecycle`, `Query`, `Presenter`, `Routing`, `PageProps`, `PageCache`, `Search`, `Seo`, `Sitemaps`, `Assets`,
  `Forms`, `Outbound`, `Webhooks`, `Access`, `Packages`, `ContentMigrations`, `Release`, `Releases`, `Eject`,
  `Install`, `Upgrade`, `Check`.
- `lib/nibble/app/` — laid out as Rails lays out `app/`, and added the same way, so names are unchanged:
  `controllers/` (`SiteController` catch-all, `Admin::*`, `Api::V1::*`, `FormsController`, `SitemapsController`,
  `AssetFilesController`), `models/` (only identity and access: users, roles, sessions, credentials, API tokens),
  `jobs/`, `mailers/`, `services/`, `helpers/`, `channels/`, `views/`.
- `lib/nibble/frontend/` — `nibble-admin/` (the control panel, `@nibble-admin`, also `@` and `~`), `nibble/` (the
  theme runtime, `@nibble`), `entrypoints/`, `ssr/`. It is Vite's `sourceCodeDir`.
- `lib/nibble/core_schema/` — the baseline schema YAML. Schema is read in three layers: this, then the theme's
  `themes/<theme>/schema/`, then the site's own `schema/`, and the last to define a handle wins.
- `app/`, `schema/`, `site/`, `content/`, `config/nibble.yml`, `config/deploy*.yml`, `db/migrate`, `Gemfile.local` — **a
  site's, not ours.** Nibble ships templates and generates them at install; it never writes them again. A site's
  own `app/` loads beside ours and its views are looked in first. `site/pages/<same path as ours>.vue` replaces a
  control panel screen, `site/slots/*.vue` replace chrome, `site/initializers/*.rb` run at boot, `site/test/` is
  for its own tests, and `content/` is where content kept as files lives — the only place a collection's `files`
  can name. `bin/rails nibble:eject <path>` is how a site takes one of our files over, recorded in
  `.nibble/`.
- `themes/<theme>/` — `layouts/`, `views/` (each `.vue` may have a `.yml` query sidecar), `views/sets/`,
  `components/`, `styles/`, `schema/`; **a theme never ships content**; `@theme` resolves to the active one,
  named in `config/nibble.yml`, then `NIBBLE_THEME`, defaulting to `crumbs`. `nibble:generate:theme` starts one.
- The documentation is not here. It is the site at `~/Projects/nibble_site`, whose `content/docs/` it is.

**Public request flow:**
1. `NibbleRedirectsMiddleware`, backed by the `redirects` table and cached.
2. Fixed routes: `/up`, `/assets/:uuid/…`, `POST /forms/:handle`, `/robots.txt`, `/sitemap.xml`, `/sitemap-:handle.xml`.
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
- **Versioned contracts:** `Nibble::SCHEMA_FORMAT`, `THEME_API_VERSION` and `CONTENT_FORMAT_VERSION` in `lib/nibble.rb`
  change only with a migration or upgrade path.

## Commands

See `README.md` for setup, running the dev server, tests/checks (`bin/ci`), seed content and
deployment commands.

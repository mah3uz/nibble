---
title: Architecture
description: The request flow, the modules, and where things live.
order: 1
---

# Architecture

Rails 8 serves both the public site and the control panel through Inertia and Vue 3 with server-side rendering.
SQLite holds the content, the cache and the job queue. Uploads go to S3 behind a CDN in production.

## Where things live

**Everything under `lib/nibble/` is Nibble's. Everything else is the site's.**

| Path | Holds |
|---|---|
| `lib/nibble/` | the engine, autoloaded as `Nibble::` |
| `lib/nibble/app/` | controllers, models, jobs, mailers, services and views, laid out as Rails lays out `app/` |
| `lib/nibble/frontend/` | `nibble-admin/` (the control panel), `nibble/` (the theme runtime), `entrypoints/`, `ssr/` |
| `lib/nibble/core_schema/` | the baseline schema YAML, the first of the three layers |
| `themes/crumbs/` | the theme Nibble ships, and the starter a site's own is copied from |
| `app/`, `schema/`, `site/`, `config/nibble.yml`, `db/migrate` | the site's |

Class names are unchanged by that layout: `Admin::EntriesController` is exactly that. A site's own `app/` loads
beside ours, and its views are looked in first.

## A public request

1. `NibbleRedirectsMiddleware` — redirects, from the table, cached.
2. Fixed routes: `/up`, `/assets/:uuid/…`, `POST /forms/:handle`, `/robots.txt`, `/sitemap.xml`.
3. The catch-all `SiteController#show` calls `Nibble::Routing.resolve`, which returns an entry, a term, a
   redirect or nothing.
4. `Nibble::PageProps` runs the view's [query sidecar](../themes/queries.md) through `Nibble::Query` and the
   `Nibble::Presenter`.
5. Inertia renders `theme/<view>` from the active theme, server-side.
6. `Nibble::PageCache` stores the response against the tags `Nibble::Dependencies` collected, echoed as
   `Surrogate-Key`.

## The modules

`Schema`, `Field`/`Fields`/`Fieldtype`, `Records::*`, `Lifecycle`, `Query`, `Presenter`, `Routing`, `PageProps`,
`PageCache`, `Search`, `Seo`, `Sitemaps`, `Assets`, `Forms`, `Outbound`, `Webhooks`, `Access`, `Packages`,
`ContentMigrations`, `Release`, `Releases`, `Eject`, `Install`, `Upgrade`, `Check`.

## The content model

Entries, terms, globals and navigation are rows whose fields live in a `data` JSON column, validated against a
blueprint built from the schema. `Nibble::Lifecycle` owns drafts, revisions, scheduling, workflow, trash and
publishing. `Nibble::Uris` keeps URIs current and records a 301 when a live record's URI changes.
`Nibble::Events` publishes through an outbox; the subscribers registered in `Nibble.boot!` update relations,
URIs, the audit log, notifications, the page cache, the search index and webhooks.

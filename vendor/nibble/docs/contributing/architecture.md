---
id: contributing-architecture
title: Architecture
description: Where Nibble's code lives, how a public request becomes a page, the content model, and the modules.
order: 1
---

# Architecture

Rails 8 serves the public site and the Control Plane, through Inertia and Vue 3 rendered on the server. SQLite holds
the content, the cache and the job queue. Uploads go to S3, or to the server's disk.

After reading this guide, you will know:

- Where Nibble's code lives, and where a site's does.
- How a public request becomes a page, step by step.
- How content is stored — as rows, and as files.
- What each module is for.

## 1. Where things live

**Everything under `vendor/nibble/` is Nibble's. Everything else is the site's.** Nibble is a Rails engine there,
read by the site's `Gemfile` and replaced whole by each release.

| Path | Holds |
|---|---|
| `vendor/nibble/lib/nibble/` | the engine, autoloaded as `Nibble::` |
| `vendor/nibble/app/` | controllers, models, jobs, mailers, services and views — laid out as Rails lays out `app/` |
| `vendor/nibble/frontend/` | `nibble-cp/` (the Control Plane), `nibble/` (the theme runtime, `@nibble`), `entrypoints/`, `ssr/` |
| `vendor/nibble/core_schema/` | the baseline schema, first of the three layers |
| `vendor/nibble/starter_content/` | the example content `nibble:install` offers |
| `vendor/nibble/themes/crumbs/` | the theme Nibble ships, which a site's own is copied from |
| `vendor/nibble/templates/` | the site's files, rendered once at install |
| `site/`, `app/`, `config/`, `test/`, `db/migrate` | the site's; never written by an upgrade |

In this repository, the root is a site too — nibble.ink — and `test/` holds Nibble's tests, which never ship.

The layout changes no names: `Nibble::Cp::EntriesController` is exactly that, rooted where a site's own `app/` can sit
beside it rather than inside it. A site's views are looked in first.

## 2. How a public request becomes a page

1. **`NibbleRedirectsMiddleware`** checks redirects before anything else, from a cached table.
2. **Fixed routes**: `/media/:uuid/…`, `POST /forms/:handle`, `/robots.txt`, `/sitemap.xml`,
   `/sitemap-:handle.xml`, `/feed.xml`, `/feed-:handle.xml`. Images written beside Markdown files are static files
   under `/nibble-assets/`.
3. **The catch-all**, `SiteController#show`, asks `Nibble::Routing.resolve` what the path is: a page written as a
   file (a hash lookup in the in-memory index), an entry, a term, a taxonomy's or collection's index, or nothing.
4. **`Nibble::PageProps`** runs the view's query sidecar through `Nibble::Query` and `Nibble::Presenter`.
5. **Inertia renders** `theme/<view>` from the active theme, on the server.
6. **`Nibble::PageCache`** stores the response against the tags `Nibble::Dependencies` collected, echoed as
   `Surrogate-Key`.

Step 6 is why queries live in a sidecar: because Nibble ran them, it knows what the page depended on, and
publishing any of it clears exactly those pages.

## 3. The content model

**Rows.** Entries, terms, globals and navigation are rows whose fields live in a `data` JSON column, validated
against a blueprint built from the schema. A new field is not a database migration.

- **`Nibble::Lifecycle`** owns everything that happens to a record: drafts, revisions, scheduling, workflow, trash
  and publishing. Nothing writes content around it.
- **`Nibble::Policy`** is asked by `Lifecycle` before every change, whoever calls it: the Control Plane, the
  management API, a job. `Lifecycle.call` takes an `actor:` — a person, a `Nibble::Principal` carrying the app they
  connected, or `Nibble::Principal.system` for Nibble's own jobs and imports — and there is no default, so no caller
  can forget who is acting. One table maps each action to the permission it needs.
- **`Nibble::Uris`** works out a record's URL when it is saved, and records a 301 when a live record's URL changes.
- **`Nibble::Events`** publishes through an outbox. Subscribers registered in `Nibble.boot!` update relations, URLs,
  the audit log, notifications, the page cache, the search index and webhooks.

**Files.** A collection with `files:` is read by `Nibble::Files` into an index at boot — and again whenever a file
changes in development. `Nibble::Files::Page` stands where a record would, answering what the presenter, routing,
queries and sitemaps ask. There are no rows, no sync and no step on the boot path.

> [!NOTE]
> The outbox matters: a publish does not do eight things inline and fail halfway. It records what happened, and the
> subscribers follow — after the commit, and again after a crash.

## 4. The modules

`Schema`, `Field`/`Fields`/`Fieldtype`, `Records::*`, `Lifecycle`, `Query`, `Presenter`, `Routing`, `PageProps`,
`PageCache`, `Dependencies`, `Files`, `Search`, `Seo`, `Sitemaps`, `Feeds`, `Assets`, `Forms`, `Outbound`,
`Webhooks`, `Events`, `Uris`, `Access`, `Packages`, `ContentMigrations`, `Drift`, `Release`, `Releases`, `Eject`,
`Install`, `Upgrade`, `Prepare`, `Metadata`, `Check`, `Principal`, `Policy`, `AgentAccess`, `Oauth`, `Operations`,
`RichTextMarkdown`, `SafeUrl`, `AgentGuide`, `Skills`, `Dev`.

`Operations` is the one list of what an app can do; `/api/v1/operations` and `/mcp` are both generated from it, and a snapshot
test makes any change to it deliberate.

Each is one idea. Looking for where something happens, the name is usually the answer.

## 5. The Control Plane

The Control Plane is the same application: controllers under `Nibble::Cp::`, rendering Vue pages through Inertia. It is
not a separate front end talking to an API, which is why a new fieldtype is one Ruby class and one Vue component
rather than a contract negotiated across a network. A site can replace any screen from `site/cp/pages/` — see
[Customising the Control Plane](../extending/control-plane.md).

## 6. Deliberately not here

No Redis, no Elasticsearch, no separate front-end application, no GraphQL. Search is SQLite's FTS5, the cache and
queue are SQLite tables, and the front end is the same application. Each is a thing nobody has to run, monitor or
pay for — and each is a choice that would be defensible the other way, for a much larger site.

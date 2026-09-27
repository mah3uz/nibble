---
id: modelling-collections
title: Collections
description: Declare a kind of content, choose the URLs its entries live at, and set how it is listed, searched,
  published and fed.
order: 1
---

# Collections

A collection is a kind of content: Tidewater's landing pages, its blog posts, its help articles. This guide covers
everything a collection file can say.

After reading this guide, you will know:

- How to declare a collection, and which keys it needs.
- How routes turn an entry into a URL, including nested pages and the home page.
- How to give a collection a listing page and an Atom feed.
- How publishing workflow, revisions, the sitemap, feeds, the API and search are set up.

## 1. A first collection

Say you want customer stories on Tidewater's site, at `/customers/<slug>`. Generate the files:

```sh
bin/rails nibble:generate:collection customers
```

and edit `site/schema/collections/customers.yml` into shape:

```yaml
schema: 1
title: Customer stories
icon: users
route: /customers/{slug}
index_route: /customers
index_template: customers/index
template: customers/show
blueprints: [story]
dated: true
sort: published_at:desc
```

Only `title` and `blueprints` are required. Everything else has a sensible default or is simply off.

> [!NOTE]
> The file name is the collection's **handle**: `customers.yml` declares `customers`. The handle is what queries,
> permissions and the API use, so choose it once. The `title` is what people see, and can change whenever you like.

## 2. Routes

### 2.1 Route patterns

`route` is the URL pattern for one entry. Tokens in braces are filled from the entry:

| Token | Becomes |
|---|---|
| `{slug}` | the entry's slug |
| `{parent_uri}` | the parent entry's whole URL, in a structured collection |
| `{parent_slugs}` | the parents' slugs, with a leading `/` |
| `{year}`, `{month}` | from the entry's publish date |
| `{locale}` | the locale's URL prefix |

```yaml
route: /blog/{year}/{slug}      # /blog/2026/late-invoices
```

A collection without a `route` has no public pages. Its entries can still be queried by other pages and read over
the API — Tidewater could keep testimonials that way and show them on the home page.

### 2.2 Changing a route

An entry's URL is worked out when the entry is saved or published, and stored. So a new `route` does not move
anything by itself: each entry takes the new pattern the next time someone saves or publishes it, and at that
moment Nibble records a **301 redirect** from its old URL.

> [!WARNING]
> Until every entry has been saved again, a collection whose route changed answers at a mix of old and new URLs.
> After changing a route on a collection with content, re-publish its entries — or plan the change for a
> collection that is still empty.

### 2.3 Nested pages and the home page

Pages live in a tree. Tidewater's `pages` collection, which Nibble ships, says so:

```yaml
route: "{parent_uri}/{slug}"
structure:
  max_depth: 5
  root: true
```

`structure` lets editors drag entries under one another, up to `max_depth` levels. With `root: true`, the
top-level entry whose slug is `home` answers at `/` — that is how Tidewater's home page works.

> [!TIP]
> `{parent_uri}` repeats the parent's *whole* URL, so a collection routed at `/docs{parent_uri}/{slug}` would give
> a child `/docs/docs/…`. Use `{parent_slugs}` when the route has its own prefix: `/docs{parent_slugs}/{slug}`.

## 3. The listing page

`index_route` gives the collection a page of its own, rendered with `index_template`:

```yaml
index_route: /blog
index_template: posts/index
```

That view receives `page` with the collection's `title`, plus whatever its [query sidecar](../theming/queries.md)
asks for — usually a paginated list of the collection's entries.

> [!NOTE]
> An entry whose URL is the same as the index route wins. If someone creates a page at `/blog`, it replaces the
> listing. That is sometimes useful, and sometimes a surprise.

## 4. Templates and layouts

```yaml
template: posts/show
layout: default
```

`template` names the [view](../theming/views.md) that renders one entry, and `layout` the frame around it. A
blueprint can set its own `template`, and so can an entry, so an unusual page does not need an unusual collection.

## 5. Dates, expiry and ordering

| Key | What it does |
|---|---|
| `dated: true` | entries carry a publish date, and can be scheduled for the future |
| `expires: true` | entries can also carry an unpublish date |
| `sort` | the default order, as `field:asc` or `field:desc` — `published_at:desc`, `title:asc`, `position:asc` |

Tidewater's blog is dated and newest first. Its pages are ordered by `position`, which is what dragging them in the
Control Plane changes.

## 6. Publishing, drafts and revisions

```yaml
workflow: review
revisions:
  keep: 100
```

- `workflow: simple` (the default) lets anyone who may publish, publish.
- `workflow: review` means an entry is **submitted for review** and approved by someone with the right role before
  it goes live. See [Drafts and publishing](../editing/publishing.md).
- `revisions.keep` is how many past versions each entry keeps.

> [!TIP]
> Turn on review once a second writer joins the blog: an editor then approves each post before it goes out, and
> the approval is recorded in the post's history.

## 7. Sitemap, feed, API and search

```yaml
sitemap:
  enabled: true
  priority: 0.6
  changefreq: weekly
feed:
  title: The Tidewater blog
  limit: 20
api: true
```

| Key | Default | What it does |
|---|---|---|
| `sitemap` | included | whether entries appear in `/sitemap.xml`, and with what priority |
| `feed` | off | `true`, or a title and limit, publishes an Atom feed at `/feed-<handle>.xml` |
| `api` | off | whether the [Content API](../theming/content-api.md) serves this collection |

Every collection with a feed also appears in `/feed.xml`. See [SEO, sitemaps and feeds](../theming/seo-and-feeds.md).

**A collection joins a search index with its own `search:` key.** Nibble's pages and posts say `search: site`; give
another collection the same to make it searchable:

```yaml
# site/schema/collections/help.yml
search: site
```

`search.yml` holds each index's settings. Write your own in `site/schema/` to choose which fields are searched:

```yaml
# site/schema/search.yml
schema: 1
indexes:
  site:
    fields: [title, intro, excerpt, description, body, blocks]
```

`fields` lists what is searched; a field a blueprint does not have is skipped. Run
`bin/rails nibble:reindex` after changing an index. Entries are indexed as they are published; a collection
[written as files](content-as-files.md) on every deploy and, in development, as soon as a file changes.

Every entry of a searched collection has an **Include in search** toggle in its sidebar, on unless someone turns it
off. Turned off, the entry is stored with `search: false` and left out of every index; a page written as a file
says the same in its front matter. A blueprint with its own `search` field keeps it, and the toggle is not added.
It does not touch the sitemap or `noindex` — those are [SEO](../theming/seo-and-feeds.md)'s.

## 8. Taxonomies and locales

```yaml
taxonomies: [topics]
localizable: true
```

`taxonomies` adds a picker for each listed [taxonomy](taxonomies.md) to every entry's sidebar, even when the
blueprint does not declare a field for it. `localizable` lets entries exist in each of the site's
[locales](../running/configuration.md).

## 9. Collections written as files

One more key changes what a collection *is*:

```yaml
files: help
```

The entries are Markdown files in `site/content/help/` instead of rows. That is how Tidewater's help centre works, and
it has a guide of its own: [Content as files](content-as-files.md).

## 10. Every key

| Key | Type | Notes |
|---|---|---|
| `title` | text | **required** |
| `blueprints` | list | **required**; the first is the default |
| `route`, `index_route` | route | see [Routes](#2-routes) |
| `template`, `index_template`, `layout` | view name | |
| `structure` | `{ max_depth, root }` or `false` | |
| `dated`, `expires`, `requires_slugs`, `localizable`, `api` | true / false | |
| `sort` | `field:direction` | |
| `workflow` | `simple` or `review` | |
| `revisions` | `{ keep }` | |
| `search` | index handle or `false` | the search index its entries join — see [Search](#7-sitemap-feed-api-and-search) |
| `sitemap` | `{ enabled, priority, changefreq }` | |
| `feed` | `true` or `{ title, limit }` | |
| `taxonomies` | list of handles | |
| `icon` | icon name | shown in the Control Plane's sidebar |
| `files` | folder in `site/content/` | see [Content as files](content-as-files.md) |

`bin/rails nibble:check` rejects any key not on this list, so a typo never passes silently.

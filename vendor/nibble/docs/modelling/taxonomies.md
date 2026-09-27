---
id: modelling-taxonomies
title: Taxonomies
description: Terms entries relate to — Tidewater's authors and topics — with pages of their own and the fields that
  point at them.
order: 3
---

# Taxonomies

A taxonomy is a set of **terms** that entries relate to. Tidewater's blog has two: the authors who write posts, and
the topics posts are about.

After reading this guide, you will know:

- How to declare a taxonomy, and give each term and the taxonomy itself a page.
- How an entry relates to terms.
- How to list a term's entries in a view.

## 1. Declaring a taxonomy

The theme Tidewater started from already declares `authors` and `topics`. Topics look like this:

```yaml
# site/themes/tidewater/schema/taxonomies/topics.yml
schema: 1
title: Topics
route: /topics/{slug}
index_route: /topics
template: topics/show
index_template: topics/index
blueprints: [topic]
sort: title:asc
api: true
```

- `route` gives each term a page: *Cash flow* lives at `/topics/cash-flow`.
- `index_route` gives the taxonomy a page listing its terms, at `/topics`.
- `blueprints` are the fields a term has, exactly as for entries — an author has a bio and a website.

Generate a new one with `bin/rails nibble:generate:taxonomy industries`. Use it to sort Tidewater's
customer stories: *Agencies*, *Consultancies*, *Studios*.

> [!NOTE]
> A taxonomy without a `route` is fine: its terms still organise entries and filter listings, they just have no
> public page. The term's `template` defaults to `taxonomies/show`, and the index's to `taxonomies/index`.

## 2. Relating entries to terms

A `terms` field on the entry's blueprint is the relationship:

```yaml
- handle: authors
  field: { type: terms, taxonomies: [authors], max_items: 1, listable: true }
- handle: topics
  field: { type: terms, taxonomies: [topics], listable: true }
```

Editors pick from the terms that exist; the field stores references, so renaming a term renames it everywhere.
Listing it (`listable: true`) adds a column and a filter to the collection's listing in the Control Plane.

Alternatively, name taxonomies on the collection and every entry gets a picker in its sidebar without the blueprint
declaring a field:

```yaml
# site/schema/collections/posts.yml
taxonomies: [topics]
```

## 3. Showing a term's entries

A term's page is rendered by its `template`. Its query sidecar asks for the entries that carry it:

```yaml
# site/themes/tidewater/views/topics/show.yml
params: [page]
posts:
  from: entries:posts
  where:
    topics: $term
  paginate: { per_page: 12 }
```

`$term` is the term being rendered — on its own it means the term's ID — as `$entry` is the entry. See
[Queries](../theming/queries.md).

> [!TIP]
> The post page can use the same idea the other way round — "more posts on this topic" — with
> `topics: { in: $entry.topics }` and `not: { id: $entry.id }`.

## 4. Every key

| Key | Notes |
|---|---|
| `title`, `blueprints` | **required** |
| `route`, `index_route` | the term page and the taxonomy page |
| `template`, `index_template`, `layout` | view names |
| `sort` | e.g. `title:asc` |
| `sitemap`, `api`, `localizable`, `search` | as for [collections](collections.md) |
| `icon` | shown in the Control Plane's sidebar |

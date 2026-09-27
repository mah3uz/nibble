---
id: theming-queries
title: Queries
description: The YAML sidecar beside a view that fetches everything the page needs — sources, conditions, sorting,
  pagination, search and forms.
order: 2
---

# Queries

A view may have a `.yml` file beside it with the same name: its **query sidecar**. Each key becomes a prop, and each
value is a query Nibble runs before rendering.

After reading this guide, you will know:

- Why a view never fetches its own content.
- Every source a query can read from, and every key it can use.
- How to filter, exclude, sort, paginate and relate.
- How to refer to the page being rendered, the URL's parameters and the current time.
- How mistakes in a query are caught.

## 1. Why a sidecar

Because Nibble runs the queries, it knows exactly what a page depended on. It caches the page against those
things, and publishing any of them clears exactly the pages that used it. A view that fetched for itself would give
all of that up.

Every Tidewater page ends with the three newest posts and the blog's topics, so the view that renders pages asks
for them:

```yaml
# site/themes/tidewater/views/pages/show.yml
latest:
  from: entries:posts
  sort: published_at:desc
  limit: 3
  fields: [title, url, excerpt, published_at]
topics:
  from: terms:topics
  fields: [title, url]
```

The view receives `latest` and `topics` as props, typed for it in `ViewProps['pages/show']`.

## 2. Sources

`from` is required; everything else is optional.

| `from` | Reads |
|---|---|
| `entries:<collection>` | published entries of a collection — rows or [files](../modelling/content-as-files.md) |
| `terms:<taxonomy>` | terms of a taxonomy |
| `search:<index>` | results from a search index, for the query in `q` |
| `form:<handle>` | a form's definition, for rendering it — see [Forms](../modelling/forms.md) |

Only published content is ever returned to a public page.

## 3. The keys

| Key | What it does |
|---|---|
| `where` | conditions a record must match |
| `not` | conditions that exclude a record |
| `sort` | `field:asc` or `field:desc`, or a list of them — a column or any field of the blueprint |
| `limit`, `offset` | a fixed slice |
| `paginate` | `{ per_page, param }` — pages, driven by a URL parameter |
| `include` | relationship fields to load in full rather than as references |
| `fields` | only these fields — smaller pages, fewer queries; `parent` adds the title and address of the page above |
| `locale` | a locale other than the page's |
| `q` | the search terms, for a `search:` source |

`paginate` and `limit` cannot be combined. `per_page` is capped at 100.

## 4. Conditions

`where` and `not` take a map of field to condition:

```yaml
where:
  published_at: { lt: $now }
  blueprint: { in: [post, announcement] }
  topics: { in: $entry.topics }
not:
  id: $entry
```

Relationship conditions compare IDs, which is why they are usually written with a variable rather than by hand.

| On | Operators |
|---|---|
| columns — `id`, `title`, `slug`, `uri`, `status`, `published_at`, `position`, `author_id`, `blueprint`, `template`, … | `eq`, `ne`, `in`, `lt`, `lte`, `gt`, `gte`, `null`, `prefix` |
| relationship fields — `entries`, `terms` | `in`, `all`, `none` |

A bare value means `eq` for a column and `in` for a relationship.

> [!WARNING]
> Only columns and relationship fields can be filtered. A condition on an ordinary field — `featured: { eq: true }`
> — is refused, because the values are not indexed and the query would have to read every entry. Model a flag you
> need to filter on as a taxonomy, or as a relationship.

## 5. Variables

A value starting with `$` is filled in when the page renders:

| Variable | Is |
|---|---|
| `$entry` | the entry being rendered; `$entry.topics` is one of its fields |
| `$term` | the term being rendered |
| `$set` | the block being rendered, in a block's own sidecar |
| `$params.<name>` | a URL parameter the sidecar declares |
| `$now` | the current time |
| `$locale` | the page's locale |

On its own, `$entry` or `$term` means the record's ID. That makes Tidewater's "related posts" a few lines:

```yaml
# site/themes/tidewater/views/posts/show.yml
related:
  from: entries:posts
  where:
    topics: { in: $entry.topics }
  not:
    id: $entry
  limit: 3
```

*Other posts in any of this post's topics, not this one, at most three.*

## 6. Pagination

```yaml
# site/themes/tidewater/views/posts/index.yml
params: [page]
posts:
  from: entries:posts
  paginate: { per_page: 12 }
```

A paginated prop arrives as `{ data, meta }`: the records, and `meta` with `current_page`, `per_page`, `total` and
`last_page`. The `Pagination` component takes `meta` and draws the links — see
[Theme components](components.md#5-pagination).

Add `scroll: true` and the next page appends to the one already shown instead of replacing it, which is what
Inertia's `InfiniteScroll` needs to load more as a reader nears the end:

```yaml
releases:
  from: entries:changelogs
  paginate: { per_page: 10, scroll: true }
```

```html
<InfiniteScroll data="releases" only-next preserve-url>
  <article v-for="release in releases.data" :key="release.id">…</article>
</InfiniteScroll>
```

> [!IMPORTANT]
> List every URL parameter a sidecar reads under `params`. Nibble ignores parameters a sidecar has not declared,
> which is what stops `?utm_source=…` from creating a new cached copy of every page.

## 7. Search

A search page reads the query from the URL:

```yaml
# site/themes/tidewater/views/search.yml
params: [q, page]
results:
  from: search:site
  q: $params.q
  paginate: { per_page: 12 }
```

Results come back most relevant first, each with a `search_snippet`: a few words around the match, the match in
`<mark>`. A collection joins an index with its own `search:` key — see
[Collections](../modelling/collections.md#7-sitemap-feed-api-and-search).

`where` narrows a search to some of its collections, so one index serves a site-wide search and a docs-only one;
`not`, `sort` and `include` do not apply:

```yaml
results:
  from: search:site
  q: $params.q
  where: { collection: $params.section }
```

A blank `section` searches everything. `fields` keeps results small, and `parent` — the title and address of the page
a result sits under — is there only when `fields` asks for it:

```yaml
  fields: [title, uri, collection, parent]
```

### Searching as you type

The search view is the whole contract: a form that sends `?q=` to its page. To show results while someone types, ask
that page for its results alone, with an Inertia partial request, instead of adding an endpoint:

```ts
import { usePage } from '@inertiajs/vue3'

const page = usePage()

async function results(q: string) {
  const response = await fetch(`/search?q=${encodeURIComponent(q)}`, {
    headers: {
      'X-Inertia': 'true',
      'X-Inertia-Version': page.version ?? '',
      'X-Inertia-Partial-Component': 'theme/search',
      'X-Inertia-Partial-Data': 'results',
    },
  })
  return response.ok ? (await response.json()).props.results.data : []
}
```

Wait for a pause in typing before asking, and cancel the request the next keystroke replaces. The answer is the same
query the page runs, published content only, so there is nothing new to secure.

## 8. Mistakes are caught, not ignored

An unknown key, an unknown field, an operator a field does not support, or a variable that does not exist is an
error — at render time in development, and in `bin/rails nibble:check`, which reads every sidecar in the theme:

```
✗ site/themes/tidewater/views/posts/show.yml: query 'related' where.featured: isn't filterable (only columns and relationship fields are)
```

A misspelled `sort` fails your check rather than quietly sorting by nothing in production.

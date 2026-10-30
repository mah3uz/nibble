---
id: theming-queries
title: Queries
description: The YAML sidecar beside a view that fetches everything the page needs — sources, conditions, sorting,
  pagination, search and forms.
order: 3
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

A form's choice field reads its options with the same `from`, `where`, `not` and `sort`; see
[Choices from content](../modelling/forms.md#15-choices-from-content).

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

A layout may have a sidecar too, in the same form, and a view's sidecar may expand the page's own relationship fields:
see [the page and layouts](#9-the-page-and-layouts).

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
| `sort` | `field:asc` or `field:desc`, or a list of them — a column or any field of the blueprint. Without it, the collection's or taxonomy's own `sort`, then `id` |
| `limit`, `offset` | a fixed slice |
| `paginate` | `{ per_page, param }` — pages, driven by a URL parameter; a bare number, `paginate: 12`, is `per_page` alone |
| `counts` | on a `terms:` source, a collection handle; each term gets `entries_count`, the entries of that collection related to it |
| `include` | relationship fields to load in full rather than as references; on a structured collection, `children` for the entries beneath each one |
| `fields` | only these fields of the blueprint — smaller pages, fewer queries. The keys every record has (`id`, `uri`, `url`, `title`…) always come too; `parent` adds the title and address of the page above |
| `locale` | a locale other than the page's |
| `q` | the search terms, for a `search:` source |

The columns a `where` or `sort` can name besides blueprint fields: for entries `id`, `uuid`, `blueprint`, `locale`,
`title`, `slug`, `uri`, `status`, `published_at`, `unpublish_at`, `parent_id`, `position`, `template`, `author_id`,
`created_at` and `updated_at`; for terms `id`, `uuid`, `blueprint`, `locale`, `title`, `slug`, `uri`, `created_at` and
`updated_at`. What comes back is described in [Content in views](content-in-views.md#2-the-shape-of-a-record).

`paginate` and `limit` cannot be combined; `offset` can. `limit` and `per_page` are between 1 and 100; a longer list paginates.

`counts` is for a list of terms that shows how many entries each holds, without a query per term. Only published,
untrashed entries in the query's locale are counted for a public page.

```yaml
topics:
  from: terms:topics
  counts: posts
```

Each term arrives with `entries_count`.

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

`limit` and `paginate.per_page` also take `$set.<field>` (or `$entry.<field>`), so an editor chooses how many a block
shows. Give a `default` for when the field is blank, as it is on a block saved before the field existed:

```yaml
# site/themes/tidewater/views/sets/latest_posts.yml
posts:
  from: entries:posts
  sort: published_at:desc
  limit: { from: $set.count, default: 3 }
```

Without a `default`, a blank field shows up to 100 for `limit` and 12 for `per_page`. A number outside 1 to 100 is
held to that range.

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

`offset` skips that many records before the pages begin, and `total` counts only what remains. A blog index that
shows a featured post above its grid takes the post with one query and starts the grid after it with another:

```yaml
featured:
  from: entries:posts
  limit: 1
posts:
  from: entries:posts
  offset: 1
  paginate: { per_page: 12 }
```

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

## 8. Children of a structured collection

On an `entries:` query of a [structured collection](../modelling/collections.md), `include: [children]` gives each
entry its published children, in tree order, one level down. A top-level query starts from the entries with no parent:

```yaml
# site/themes/tidewater/layouts/default.yml
menu:
  from: entries:pages
  where: { parent_id: { null: true } }
  include: [children]
  fields: [title, url]
```

Each entry arrives with a `children` list, which a mega-menu draws as columns. Children are not expanded further, and
`fields` applies to them as well.

## 9. The page and layouts

A layout has a sidecar of its own, `layouts/<name>.yml`, in the same form as a view's. Its props reach every page that
uses the layout, the 404, search and preview pages included, and the layout receives them as props:

```vue
<script setup lang="ts">
import type { LayoutProps } from '@site/types'

defineProps<LayoutProps['default']>()
</script>
```

A layout the theme does not have renders as `default`, so it takes `default`'s sidecar. Its `params` are declared for
every page.

Layouts that share a header share its queries with `extends`, which takes the queries, `params` and page includes of
another layout's sidecar; a query of the same name in the extending sidecar wins:

```yaml
# site/themes/tidewater/layouts/docs.yml
extends: default
sections:
  from: entries:docs
  where: { parent_id: { null: true } }
```

A layout's queries run for every page, so keep them small. Editing an entry of a collection a layout queries clears
every page that uses the layout.

`page` is the record being rendered, so a sidecar key named `page` with no `from` is not a query: `include` under it
expands the page's own relationship fields.

```yaml
# site/themes/tidewater/views/posts/show.yml
page:
  include: [authors]
```

A view's and its layout's lists are combined. A record whose blueprint lacks a listed field is skipped, so one
sidecar can serve blueprints that differ. `children` may be listed here too. A `page` entry with a `from` is an
ordinary query that hides the page, and `nibble:check` warns about it.

A layout's query may not be named `page`, `layout`, `site`, `seo` or `preview`, which every page already has, nor like
one of a view's queries; if they clash anyway, the view's wins.

## 10. Mistakes are caught, not ignored

An unknown key, an unknown field, an operator a field does not support, or a variable that does not exist is an
error — at render time in development, and in `bin/rails nibble:check`, which reads every view and layout sidecar in the theme:

```
✗ site/themes/tidewater/views/posts/show.yml: query 'related' where.featured: isn't filterable (only columns and relationship fields are)
```

A misspelled `sort` fails your check rather than quietly sorting by nothing in production.

---
title: Queries
description: The .yml sidecar beside a view, and what it hands the page.
order: 4
---

# Queries

A view may have a `.yml` file beside it. Each key becomes a prop; each value is a query run before the page
renders, so a view never fetches anything itself.

```yaml
# views/guides/index.yml
params: [page]
guides:
  from: entries:guides
  where:
    region: { in: $entry.regions }
  not:
    id: $entry.id
  sort: published_at:desc
  paginate: { per_page: 12 }
```

## Keys

`from` is required; the rest are optional.

| Key | Does |
|---|---|
| `from` | the source: `entries:<collection>`, `terms:<taxonomy>`, `search`, `form:<handle>` |
| `where` / `not` | conditions to include or exclude |
| `q` | the search term, for a `search` source |
| `locale` | restrict to one locale |
| `sort` | `field:asc` or `field:desc` |
| `paginate` | `{ per_page:, param: }`, capped at 100 per page |
| `limit` / `offset` | a fixed slice instead of pagination |
| `include` | related records to load with it |
| `fields` | only the fields the view uses |

Conditions take `eq`, `ne`, `in`, `lt`, `lte`, `gt`, `gte`, `null` and `prefix`; relationship fields take `in`,
`all` and `none`. `$entry.<field>` refers to the record being rendered, which is how a "related guides" query
knows what it is related to.

An unknown key is an error, not a silent no-op: `bin/rails nibble:check` reports it.

## Pagination

A paginated prop arrives as `{ data, pagination }`. `@nibble`'s [`Pagination`](helpers.md) component renders the
links.

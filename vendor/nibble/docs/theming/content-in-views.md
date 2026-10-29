---
id: theming-content-in-views
title: Content in views
description: What a view receives — the page props, the shape of a record, what each fieldtype's value looks like,
  the generated type names, and the shape of globals and menus.
order: 2
---

# Content in views

A view is handed plain data and draws it. This guide is the reference for that data: the props every view gets, the
shape of an entry or term, how each fieldtype arrives, and the types that describe all of it.

After reading this guide, you will know:

- Which props every view receives.
- The fields every record carries, and when to use `uri` and when `url`.
- What each fieldtype's value looks like in a view.
- Where the generated type names come from and what they mean.
- What a global and a menu look like.

## 1. The props of a view

| Prop | What it is |
|---|---|
| `page` | the entry, term or file page being rendered: the [record](#2-the-shape-of-a-record) and its fields |
| one prop per sidecar query | whatever the [query sidecar](queries.md) asked for, under the name the sidecar gave it |
| `site` | `locale`, `url` (this page's absolute URL), `params`, `globals` and `navigation` |
| `seo` | the title, description, canonical URL, robots and image `SeoHead` renders |
| `layout` | the name of the layout wrapping the page |
| `preview` | `{ label, edit_url }` while an editor previews a draft, otherwise `null` |

`site.params` holds only the URL parameters a sidecar declared with `params:`, those of the view's own sidecar and of
every set's. Anything else on the query string, such as `?utm_source=`, is stripped from the props, so a page's
output depends only on parameters Nibble knows about.

You rarely read `site`, `seo` or `preview` directly. The [composables](components.md#7-shared-props) read `site`,
`SeoHead` reads `seo`, and `PreviewBar` reads `preview`.

`page` for a term is the term, with `taxonomy` in place of `collection`. The 404 view's `page` is `{ title: "Page not found" }`.

## 2. The shape of a record

Every `page`, and every item of every query, carries these keys:

| Key | Value |
|---|---|
| `id` | the numeric id |
| `uuid` | the record's stable identifier, the one the [Content API](../extending/content-api.md) addresses it by |
| `type` | `entry` or `term` |
| `collection` or `taxonomy` | the handle it belongs to |
| `blueprint` | the blueprint's handle |
| `locale` | the locale code |
| `title` | the title |
| `slug` | the last part of its address |
| `uri` | its path on this site, such as `/blog/hello`, or `null` if it has no page |
| `url` | the absolute address: the site's URL plus `uri` |
| `status` | the entry's status; `null` where the record has none |
| `published_at` | an ISO 8601 UTC time, or `null` |
| `updated_at` | an ISO 8601 UTC time |
| `author` | `{ id, name }` of the entry's author, or `null` |

Your blueprint's fields follow, one key per field handle, shaped as in [section 3](#3-what-each-fieldtype-looks-like).
Three more keys appear only when asked for: `parent` (`{ title, uri }`, when the sidecar's `fields` lists it),
`search_snippet` (on [search](queries.md) results) and `entries_count` (when the query sets `counts`).

> [!IMPORTANT]
> **`uri` is a path and `url` is absolute. Put `uri` in an `href`.** A path keeps a visitor on whatever host they are
> on, and works under `<Link>`; use `url` where an absolute address is needed, such as a canonical link or a "copy
> link" button. Menu items are the exception: their `url` is already a path for a record link, and the address as
> written for an external link. See [section 5](#5-globals-and-menus).

```vue
<Link v-for="post in posts.data" :key="post.id" :href="post.uri!">{{ post.title }}</Link>
<p>By {{ page.author?.name }}, updated {{ page.updated_at }}</p>
```

A query that sets `fields:` still returns `id`, `uuid`, `type`, `blueprint`, `locale`, `title`, `slug`, `uri`, `url`,
`status`, `published_at`, `updated_at` and `author`; `fields` chooses which of the blueprint's fields come with them.

A field marked `api: false` is on `page` but missing from the generated types, so reading it is a type error until
you cast the page.

## 3. What each fieldtype looks like

| Fieldtype | The value in a view |
|---|---|
| `text`, `textarea`, `slug`, `color`, `code`, `time` | a string, or `null` when empty. `code` is the raw source; `color` is `#rrggbb`. A `text` field with `input_type: number` is a number |
| `integer`, `decimal`, `range`, `rating`, `calculation` | a number, or `null` |
| `toggle` | a boolean |
| `date` | an ISO 8601 string: `2026-10-30` for a date, UTC `2026-10-30T09:30:00Z` when `time_enabled`, or with an offset when the field names a `time_zone`; `null` when empty |
| `select`, `radio`, `button_group` | `{ value, label }`; when `multiple`, a list of them |
| `checkboxes` | a list of `{ value, label }` |
| `list` | a list of strings |
| `link` | `{ type, url, id?, title? }` or `null`. A web, email or phone link is `{ type: 'url', url }`; a link to a record carries its `id` and `title`, and its `url` is the record's path |
| `assets` | an `AssetValue`, or a list of them when the field allows several. Hand it to `Image` |
| `entries`, `terms` | an `EntrySummary` or `TermSummary`, or a list of them. With `include:` in the sidecar the full record takes its place, down to two levels |
| `markdown` | an HTML string, rendered and sanitised on the server, or `null`. Hand it to `RichText` |
| `rich_text` | an HTML string, or `null`. When the field has sets, a list of `{ type: 'text', text }` parts and set blocks instead; `RichText` draws either |
| `replicator` | a list of blocks, each its set's fields plus `id` and `type`. Hand it to `Blocks` |
| `grid` | a list of rows, each the row's fields plus an `id` |
| `files` | a list of `{ id, filename, size, content_type }` |
| `seo` | an object: `title`, `exact_title`, `description`, `canonical`, `og_image`, `noindex`, `nositemap`, `schema_type`, `json_ld_overrides` |
| `secret` | always `null`; a secret never reaches a page |
| `note` | not a value; display-only fields are left out |

An `EntrySummary` is `{ id, type: 'entry', title, uri, url, collection }`, a `TermSummary` the same with `taxonomy`,
and an `AssetValue` is `{ id, title, filename, kind, url, alt, width?, height?, srcset?, focal? }`. `Image` applies
`focal` to the picture as its `object-position`, so a crop keeps the editor's chosen point.

`include:` is how a related record's own fields arrive. Without it an `entries` value is the summary, enough for a
link:

```yaml
posts:
  from: entries:posts
  include: [author]
```

## 4. Multi-language sites

`useLocale()` returns the page's locale code and `site.locale` is the same string. `site.url` is the page's own
address, with the locale's `url_prefix` in it. A record carries its own `locale`. Globals and menus arrive in the
page's locale, so a header built from them is already translated.

What a theme does not receive is the list of a record's translations: there is no prop for "this page in other
languages". A language switcher links to each locale's home page, built from the site's locales, rather than to the
sibling of the page being viewed. The theme's own interface strings, such as "Read more", belong in the theme: keep a
small map keyed by locale and look it up with `useLocale()`.

## 5. Globals and menus

A global arrives as an object of its fields, each shaped as in section 3, plus its `handle` and `locale`. All of them
are on `site.globals`, keyed by handle; `useGlobals('site')` reads one. Type it with the generated `SiteGlobals` for a
global whose handle is `site`, `<Handle>Globals` for the rest:

```ts
import { useGlobals } from '@nibble'
import type { SiteGlobals } from '@site/types'

const company = useGlobals<SiteGlobals>('site')
```

A menu is a list of items, and `useNavigation('footer')` returns it:

| Key | Value |
|---|---|
| `type` | `url` for an address someone typed, otherwise `entry` or `term` |
| `id` | the record's id, for a record link |
| `title` | the label; for a record link, its title unless the menu overrode it |
| `url` | the address as typed for `url`; the record's path for a record link |
| `children` | the same items, nested |

A link to a record that no longer exists is left out of the menu.

## 6. The generated types

`site/types.d.ts` is written from your schema by the generators and `bin/rails nibble:schema:types`; never edit it.
Import from `@site/types`.

| Type | What it is |
|---|---|
| `PostsPost`, `PagesPage`… | one blueprint's record: `<Collection><Blueprint>`, and `<Taxonomy><Blueprint>` for terms |
| `PostsEntry`, `TopicsTerm` | the union of a collection's or taxonomy's blueprints |
| `RecordBase` | the keys every record has; the interfaces above extend it |
| `EntrySummary`, `TermSummary`, `AssetValue` | what relation and asset fields hold |
| `ParentSummary` | `{ title, uri }`, the `parent` key |
| `Paginated<T>`, `PaginationMeta` | `{ data: T[]; meta }` for a [paginated query](queries.md#6-pagination), and its `meta` |
| `ViewProps['posts/index']` | the props one view's sidecar produces, keyed by view name |
| `ViewProps['sets/pricing']` | the same for a set's sidecar, as its `queries` prop |
| `SiteGlobals`, `<Handle>Globals` | a global's fields |
| `FormValues['demo']`, `DemoFormValues` | the values a form collects; see [Forms](forms.md) |

```vue
<script setup lang="ts">
import type { PostsPost, ViewProps } from '@site/types'

defineProps<ViewProps['posts/show'] & { page: PostsPost }>()
</script>
```

`@nibble` exports a few types of its own for the shared props: `SiteProps`, `Link` (a menu item), `RecordSummary`,
`SetBlock`, `RichTextValue`, `ImageValue`, `PaginationMeta`, `SeoProps` and the `NibbleForm…` family. Where `@site/types`
has the same idea, such as `EntrySummary` for `RecordSummary` or `AssetValue` for `ImageValue`, use `@site/types`: it is
the one generated from your schema. `Link` as a type is a menu item; it is unrelated to Inertia's `Link` component, so
import the component under that name and rename the type if you need both.

## 7. What's next

- [Queries](queries.md) — asking for the records a page needs.
- [Theme components](components.md) — drawing rich text, images and blocks.
- [Styling and the page shell](styling-and-shell.md) — links, head tags and CSS.

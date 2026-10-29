---
id: theming-views
title: Views and layouts
description: Which view renders which page, what a view receives, layouts, blocks and error pages.
order: 1
---

# Views and layouts

A view is a Vue single-file component that renders one kind of page. This guide covers how Nibble chooses one,
what it receives, and the layouts, blocks and error pages around it.

After reading this guide, you will know:

- How Nibble decides which view renders a request.
- What props every view receives, and how to type them.
- How to generate a view, and wire it to a collection.
- How layouts, blocks and error pages work.

## 1. Which view renders a request

Once a URL has been resolved, the view is the first of these that is set:

| For | View |
|---|---|
| an entry | its own `template`, then its blueprint's, then its collection's, then `default` (`crumbs` ships one; `nibble:check` warns when a routed collection's entries resolve to a view the theme doesn't have) |
| a page written as a file | its frontmatter's `template`, then the same chain |
| a taxonomy term | its taxonomy's `template`, then `taxonomies/show` |
| a collection's index route | its `index_template`, then `collections/index` |
| a taxonomy's index route | its `index_template`, then `taxonomies/index` |
| nothing | `errors/404` |

`collections/index` and `taxonomies/index` are used only by a collection or taxonomy that sets an `index_route`
without an `index_template`; `nibble:check` reports one whose view is missing.

A view name is a path under `views/` without `.vue`: `posts/show` is `site/themes/tidewater/views/posts/show.vue`.

> [!IMPORTANT]
> Every theme must have the views `pages/show`, `posts/show`, `posts/index`, `taxonomies/show`, `taxonomies/index`,
> `search`, `errors/404` and `errors/500`, and the layout `layouts/default.vue`. `nibble:check` names any that are
> missing. A theme generated from `crumbs` has them all.

That order is why an unusual page does not need an unusual collection. Tidewater's "Book a demo" page is an
ordinary page whose own **Template** is set to `demo`.

## 2. Generating a view

```sh
bin/rails nibble:generate:view customers/show --collection=customers
```

writes `views/customers/show.vue`, typed for the collection's first blueprint, and `views/customers/show.yml`, a
query sidecar listing the collection's entries, then tells you the line to add to the collection:

```
wrote site/themes/tidewater/views/customers/show.vue
  add template: customers/show to schema/collections/customers.yml to use it
```

Delete the sidecar if the view needs nothing but its own page. If the browser console reports
`Page not found: theme/customers/show` while `bin/dev` is running, restart it.

## 3. What a view receives

| Prop | What it is |
|---|---|
| `page` | the entry, term or file page being rendered, with its fields |
| one prop per sidecar query | whatever the [query sidecar](queries.md) asked for |
| `site` | the locale, the URL, every global and every navigation — usually read through [composables](components.md) |
| `seo` | the title, description, canonical URL and social tags `SeoHead` renders |
| `layout`, `preview` | used by Nibble's own components |

[Content in views](content-in-views.md) lists the keys of every record and what each fieldtype's value looks like.

Types for all of it are generated from your schema:

```vue
<!-- site/themes/tidewater/views/posts/show.vue -->
<script setup lang="ts">
import { Image, RichText } from '@nibble'
import type { PostsPost, ViewProps } from '@site/types'

const props = defineProps<ViewProps['posts/show'] & { page: PostsPost }>()
</script>

<template>
  <article>
    <h1>{{ page.title }}</h1>
    <p v-if="page.excerpt">{{ page.excerpt }}</p>
    <Image v-if="page.featured_image" :image="page.featured_image" sizes="(min-width: 60rem) 60rem, 100vw" />
    <RichText :value="page.body" />
  </article>
</template>
```

`ViewProps['posts/show']` types what the sidecar returns; `PostsPost` types the page. A field that does not exist
is a type error. Check the whole theme with `npx vue-tsc -p tsconfig.app.json --noEmit` before it is a broken page.

> [!IMPORTANT]
> A view never fetches its own content — no `fetch`, no API calls. Put what it needs in its sidecar, so Nibble
> knows what the page depended on and can clear its cache precisely.

## 4. Layouts

A layout is the frame around a page: header, footer, the `<head>` tags. `layouts/default.vue` wraps everything
unless a collection or taxonomy names another:

```yaml
# site/schema/collections/help.yml
layout: help
```

Tidewater's help centre uses `layouts/help.vue` — a slimmer header with a search box and no marketing navigation.
A layout name that does not exist falls back to `default`.

```vue
<!-- site/themes/tidewater/layouts/default.vue -->
<script setup lang="ts">
import { PreviewBar, SeoHead } from '@nibble'
import SiteHeader from '../components/SiteHeader.vue'
import SiteFooter from '../components/SiteFooter.vue'
</script>

<template>
  <SeoHead />
  <PreviewBar />
  <SiteHeader />
  <main><slot /></main>
  <SiteFooter />
</template>
```

> [!WARNING]
> Keep `<SeoHead />` in every layout. Without it a page has no title, description or canonical link, and search
> engines see an unlabelled page.

## 5. Blocks

Each set of a `replicator` field is drawn by `views/sets/<set handle>.vue`, which receives the set's fields as
props. `Blocks` loops over a field's blocks and picks the right component for each:

```vue
<Blocks :blocks="page.blocks" />
```

The block's own `id` and `type` are not passed, so they do not land on your root element as HTML attributes. A
`select` field reaches the view as `{ value, label }`, or a list of them when it allows several.

A set can run queries of its own. Put a sidecar beside its view, `views/sets/<set handle>.yml`, in the same form as a
[view's](queries.md), and the results arrive as the `queries` prop. `$set` in it is the block's own values:

```yaml
# views/sets/related_posts.yml
posts:
  from: entries:posts
  topics: { in: $set.topics }
```

```vue
<script setup lang="ts">
defineProps<{ heading: string; queries: { posts: PostsPost[] } }>()
</script>
```

A block whose set has no view renders nothing, so adding a set to a blueprint before its view exists is safe. `nibble:check` warns about it so the missing view is not forgotten.

A set's sidecar may declare `params` too. They are added to the parameters of every page, so a block can read a URL
parameter the page's own view never mentions.
Tidewater's pricing block is built end to end in
[Getting Started](../getting-started/tutorial.md#42-a-block-of-your-own-pricing).

## 6. Error pages

`views/errors/404.vue` renders every address that resolves to nothing, and `views/errors/500.vue` renders a page
that failed — both inside the default layout, so they look like the rest of the site. The 404 view may have a query
sidecar, `views/errors/404.yml`, like any view. The 500 view receives the same `site`, globals and navigation as any
page when they can be loaded, and empty props when loading them fails, so a layout should tolerate both.

> [!TIP]
> Every 404 is counted, most-requested first, on the Control Plane's **Missing pages** screen at `/cp/404s`, and
> in the dashboard's **Top missing pages** widget. It is the quickest way to find a link that broke. See
> [Fix search results, share cards and broken links](../editing/redirects-and-seo.md).

## 7. What's next

- [Content in views](content-in-views.md) — what `page` and the other props hold.
- [Styling and the page shell](styling-and-shell.md) — `theme.css`, links, head tags and code highlighting.

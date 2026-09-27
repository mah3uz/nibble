---
id: theming-views
title: Views and layouts
description: Which view renders which page, what a view receives, layouts, blocks, error pages and code
  highlighting.
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
- How to highlight code blocks.

## 1. Which view renders a request

Once a URL has been resolved, the view is the first of these that is set:

| For | View |
|---|---|
| an entry | its own `template`, then its blueprint's, then its collection's, then `default` |
| a page written as a file | its frontmatter's `template`, then the same chain |
| a taxonomy term | its taxonomy's `template`, then `taxonomies/show` |
| a collection's index route | its `index_template`, then `collections/index` |
| a taxonomy's index route | its `index_template`, then `taxonomies/index` |
| nothing | `errors/404` |

A view name is a path under `views/` without `.vue`: `posts/show` is `site/themes/tidewater/views/posts/show.vue`.

> [!IMPORTANT]
> Every theme must have `pages/show`, `posts/show`, `posts/index`, `taxonomies/show`, `taxonomies/index`, `search`,
> `errors/404` and `errors/500`. `nibble:check` names any that are missing. A theme generated from `crumbs` has them
> all.

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

Delete the sidecar if the view needs nothing but its own page. Then restart `bin/dev`, since the view is a new file.

## 3. What a view receives

| Prop | What it is |
|---|---|
| `page` | the entry, term or file page being rendered, with its fields |
| one prop per sidecar query | whatever the [query sidecar](queries.md) asked for |
| `site` | the locale, the URL, every global and every navigation — usually read through [composables](components.md) |
| `seo` | the title, description, canonical URL and social tags `SeoHead` renders |
| `layout`, `preview` | used by Nibble's own components |

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
is a type error, caught by `npm run check` before it is a broken page.

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

A block whose set has no view renders nothing, so adding a set to a blueprint before its view exists is safe.
Tidewater's pricing block is built end to end in
[Getting Started](../getting-started/tutorial.md#42-a-block-of-your-own-pricing).

## 6. Error pages

`views/errors/404.vue` renders every address that resolves to nothing, and `views/errors/500.vue` renders a page
that failed — both inside the default layout, so they look like the rest of the site.

> [!TIP]
> Every 404 is counted, most-requested first, on the Control Plane's **Missing pages** screen at `/cp/404s`, and
> in the dashboard's **Top missing pages** widget. It is the quickest way to find a link that broke. See
> [Redirects and SEO](../editing/redirects-and-seo.md).

## 7. Highlighting code

Nibble renders a fenced code block as `<pre><code class="language-ruby">`, the shape Prism, highlight.js and Shiki
all look for, and stops there. **Highlighting is the theme's decision** — a site that publishes no code carries no
highlighter.

Tidewater's help centre shows code for its API, so its theme highlights in the browser, loading only the languages a
page uses. The theme copied from `crumbs` already does this in `lib/highlight.ts`, with highlight.js as the theme's
own dependency.

> [!NOTE]
> Nibble does not highlight on the server on purpose: server-side highlighting writes inline colours in a theme of
> its own choosing, which no stylesheet of yours could override.

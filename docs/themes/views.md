---
title: Views
description: Which view renders what, and the layouts and sets around it.
order: 3
---

# Views

A view is a Vue single-file component under `themes/<yours>/views/`, rendered on the server and hydrated in the
browser.

```
themes/almanac/
  layouts/default.vue
  views/home.vue
  views/home.yml
  views/guides/index.vue
  views/guides/show.vue
  views/sets/quote.vue
  components/PostCard.vue
  styles/theme.css
```

## Which view renders a request

`Nibble::Routing` resolves the path to an entry, a term or a taxonomy index, and the view is the first of these
that is set: the entry's own `template`, its blueprint's, its collection's, then `default`. Terms use the
taxonomy's `template`, defaulting to `taxonomies/show`.

Generate one wired to a collection:

```sh
bin/rails nibble:generate:view guides/index --collection=guides
```

It writes the view, its [query sidecar](queries.md), and tells you the line to add to the collection.

## Props

Every view gets `page` — the record being rendered — plus whatever its sidecar asked for, and shared props for
the site, its globals and its navigation:

```vue
<script setup lang="ts">
import type { ViewProps, GuidesGuide } from '../../.nibble/types'

defineProps<ViewProps['guides/show'] & { page: GuidesGuide }>()
</script>
```

## Layouts and sets

`layouts/default.vue` wraps every view; a page can name another with a `layout` field. `views/sets/<type>.vue`
renders one set of a replicator field, which is how a page assembled from blocks is drawn.

`views/errors/404.vue` and `views/errors/500.vue` render those responses.

## Styles

`styles/theme.css` is the theme's stylesheet, built by Vite. Themes are npm workspaces, so a theme may have
dependencies of its own — add them with `npm install <package> -w @nibble-theme/<yours>` and commit the lockfile.

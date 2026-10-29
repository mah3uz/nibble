---
id: theming-styling
title: Styling and the page shell
description: The stylesheet a theme owns, Tailwind, dark mode, fonts, the HTML shell Nibble writes around every page,
  links and head tags, code that runs under server rendering, code highlighting, and the Pagination and PreviewBar
  slots.
order: 6
---

# Styling and the page shell

A theme owns the body of a page and its stylesheet. Nibble owns the HTML around them. This guide covers both sides of
that line: how to style a theme, what the shell already does, and the rules for code that runs on the server before
it runs in the browser.

After reading this guide, you will know:

- Which stylesheet Nibble links, and how Tailwind fits in.
- How to support light and dark, and what the `nibble_theme` cookie does.
- What the shell writes and what a theme adds to `<head>`.
- Why on-site links use `<Link>`.
- How to keep code safe under server rendering.
- How to highlight code and customise `Pagination` and `PreviewBar`.

## 1. The stylesheet

Nibble links one stylesheet from the active theme: `styles/theme.css`. Anything else must be reached from it with
`@import`, which is how `crumbs` pulls in `highlight.css`. Vite builds it, so edits show on the next reload.

Nibble provides Tailwind CSS v4 and its typography plugin; a theme does not install them. The `theme.css` copied from
`crumbs` shows the setup:

```css
@import 'tailwindcss' source(none);
@plugin '@tailwindcss/typography';
@source '../';

@theme {
  --color-accent: #b81953;
  --font-display: 'Londrina Solid', sans-serif;
}
```

`source(none)` plus `@source '../'` tells Tailwind to scan only the theme's own folder for class names, so a utility
used in a view or component is generated and one used nowhere is not. Design tokens go in `@theme`, and become
utilities such as `text-accent` and `font-display`.

You do not have to use Tailwind. A `theme.css` of plain CSS, or one that imports another preprocessor's output, works
the same; drop the Tailwind lines and the dependency stays unused.

### Fonts

Load a font with `@import url(...)` at the top of `theme.css`, as `crumbs` does with Google Fonts, or self-host a file
under the theme and reference it with `@font-face`. Name it in `@theme` as a `--font-*` token so utilities use it.

## 2. Light and dark

Tailwind's `dark:` variant needs to know when dark applies. `crumbs` defines it to follow the visitor's choice first
and the system setting second:

```css
@custom-variant dark {
  &:where([data-theme='dark'], [data-theme='dark'] *) {
    @slot;
  }
  @media (prefers-color-scheme: dark) {
    &:where(:root:not([data-theme]), :root:not([data-theme]) *) {
      @slot;
    }
  }
}
```

A visitor's explicit choice lives in the `data-theme` attribute of `<html>`, `light` or `dark`. With none, the
system's `prefers-color-scheme` decides.

To make the first paint match a saved choice, store it in a cookie named `nibble_theme` with the value `light` or
`dark`:

```ts
document.cookie = `nibble_theme=${theme}; path=/; max-age=31536000; samesite=lax`
document.documentElement.dataset.theme = theme
```

The shell reads that cookie and writes it into `<html data-theme>` on the server, so a returning visitor's page
arrives already in their register, with no flash of the other one. Any other value is ignored. Because the cookie
changes the HTML, the [page cache](index.md#3-how-a-page-is-rendered) keeps a separate copy per choice, so a visitor
who has chosen never gets another visitor's copy.

> [!NOTE]
> The theme switch in `crumbs` keeps the choice in `localStorage` instead, so a returning visitor's saved dark mode is
> applied after the page loads. Write the cookie as above in your own theme and the page is right from the first paint.

## 3. The HTML shell

Nibble writes `<html>`, `<head>` and the scripts. A theme never ships a document; its layout is the content of
`<body>`. The shell includes, in order:

- the `lang` attribute from the page's locale and the `data-theme` attribute from the cookie above;
- the title, description, canonical and robots tags, Open Graph and Twitter tags, structured data, the favicon and any
  verification tags, all from the page's [SEO](seo-and-feeds.md);
- a link to the site's feed, where there is one;
- the theme's `styles/theme.css`;
- the scripts that start the app, and any [integrations](../running/configuration.md) the site added.

To add tags of your own, such as a font preload or a per-view `<meta>`, use Inertia's `Head` component anywhere in a
view or layout:

```vue
<script setup lang="ts">
import { Head } from '@inertiajs/vue3'
</script>

<template>
  <Head>
    <link rel="preload" href="/fonts/display.woff2" as="font" type="font/woff2" crossorigin />
  </Head>
</template>
```

Give a tag you may repeat a `head-key` so a later one replaces the earlier instead of adding to it. The title,
description, canonical and robots tags are `SeoHead`'s; do not write them again.

## 4. Links

Pages are a single-page app after the first load. A link written with Inertia's `Link` component moves between pages
without reloading the document, while a plain `<a href>` reloads it:

```vue
<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
</script>

<template>
  <Link :href="post.uri!">{{ post.title }}</Link>
</template>
```

Use `Link` for every on-site address, and a plain `<a>` for external ones, downloads and `mailto:`. Put a record's
`uri`, not its `url`, in the `href`; see [Content in views](content-in-views.md#2-the-shape-of-a-record).
`usePage()` from the same package gives the current `url`, `props` and component, for an "active link" style.

> [!NOTE]
> A theme may import `@nibble`, `@theme`, relative paths, `@site/types` and its own dependencies, and may also import
> `vue` and `@inertiajs/vue3`, both of which Nibble provides. `crumbs` does. `npm run lint` rejects only the paths
> `@/*`, `~/*` and anything under `vendor/nibble/frontend`, which are Nibble's internals.

`@nibble` also exports a type named `Link`. It is a menu item, not Inertia's component; see
[Content in views](content-in-views.md#6-the-generated-types).

## 5. Code that runs on the server

Every page is rendered on the server first and then hydrated in the browser. During the server pass there is no
`window`, `document` or `localStorage`, and reading one throws and fails the page. Keep browser-only code where it
runs only in the browser:

```vue
<script setup lang="ts">
import { onMounted, ref } from 'vue'

const dark = ref(false)

onMounted(() => {
  dark.value = window.matchMedia('(prefers-color-scheme: dark)').matches
})
</script>
```

`onMounted` runs only in the browser, so the server and the first browser render agree and hydration succeeds. The
same goes for anything random or time-dependent in a template: `Math.random()` or `new Date()` in the markup makes the
server and the browser disagree. Compute them in `onMounted`.

## 6. Highlighting code

Nibble renders a fenced code block as `<pre><code class="language-ruby">`, the shape Prism, highlight.js and Shiki
all look for, and stops there. **Highlighting is the theme's decision** — a site that publishes no code carries no
highlighter.

Tidewater's help centre shows code for its API, so its theme highlights in the browser, loading only the languages a
page uses. The theme copied from `crumbs` already does this in `lib/highlight.ts`, with highlight.js as the theme's
own dependency and `styles/highlight.css` for the colours.

> [!NOTE]
> Nibble does not highlight on the server on purpose: server-side highlighting writes inline colours in a theme of
> its own choosing, which no stylesheet of yours could override.

## 7. Pagination and PreviewBar slots

Both components draw default markup that most themes replace.

`Pagination` takes `meta` from a paginated query, `param` (the URL parameter, `page` by default) and `label` (the
`aria-label` of its `<nav>`, `Pagination` by default). It renders nothing when there is one page. Its default slot
receives the page numbers and a function that builds each link:

```vue
<Pagination :meta="posts.meta" label="Posts">
  <template #default="{ pages, href, current }">
    <Link v-for="number in pages" :key="number" :href="href(number)" :class="{ active: number === current }">
      {{ number }}
    </Link>
  </template>
</Pagination>
```

| Slot scope | |
|---|---|
| `pages` | the page numbers, `[1, 2, 3, …]` |
| `href(number)` | the on-site address of that page, keeping the rest of the query string |
| `current` | the current page number |

`PreviewBar` shows only while an editor previews a draft. Its default slot receives `preview`, with a `label` and an
`edit_url`; `edit_url` is always `null` on a public page, so a link to edit is not offered there. Replace the ribbon
and keep the component, since it also lets Live Preview update the page in place:

```vue
<PreviewBar>
  <template #default="{ preview }">
    <div class="draft-banner">Draft: {{ preview.label }}</div>
  </template>
</PreviewBar>
```

## 8. What's next

- [Theme components](components.md) — rich text, images, blocks and SEO.
- [Content in views](content-in-views.md) — what the props hold.
- [SEO, sitemaps and feeds](seo-and-feeds.md) — the tags the shell writes.

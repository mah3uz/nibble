---
id: theming-components
title: Theme components
description: The components and composables @nibble gives every theme — rich text, images, blocks, pagination, SEO,
  shared props and forms.
order: 3
---

# Theme components

`@nibble` is the theme runtime: a handful of components and composables for the things every theme needs. This
guide shows each one as Tidewater's theme uses it.

After reading this guide, you will know:

- How to render rich text and Markdown safely.
- How to render images at the right size.
- How blocks, pagination and SEO tags are drawn.
- How to read globals and menus from anywhere.
- How to build a working form.

```ts
import {
  RichText, Image, Blocks, Pagination, SeoHead, PreviewBar,
  useSite, useGlobals, useNavigation, useLocale, useNibbleForm,
} from '@nibble'
```

## 1. Rich text

```vue
<RichText :value="page.body" />
```

A `rich_text` field is stored as structured data and rendered to HTML on the server, through an allowlist that strips
`script` elements, `on*` attributes and `javascript:` URLs. A `markdown` field is rendered on the server the same
way. `RichText` puts the result on the page, and draws any blocks embedded in the text with their set views.

> [!CAUTION]
> Do not render content with `v-html` yourself. `RichText` is where the sanitising is tested; a hand-rolled
> `v-html` on a field is where a script tag written by someone with an editor account reaches every visitor.

## 2. Images

An `assets` field names the size it is for:

```yaml
- handle: featured_image
  field: { type: assets, max_files: 1, alt: required, preset: hero }
```

and the view renders the value it receives:

```vue
<Image :image="page.featured_image" sizes="(min-width: 64rem) 64rem, 100vw" />
```

| Prop | |
|---|---|
| `image` | the asset value: `url`, `alt`, `width`, `height` and, when the preset has one, `srcset` |
| `sizes` | how wide the image is drawn — defaults to `100vw` |
| `loading` | `lazy` (the default) or `eager` for the first image on the page |

The image is served through Nibble's own transform endpoint at the preset's size, cropped around the focal point an
editor set, and cached by content — re-cropping gives it a new URL rather than a stale one. Alt text comes from the
asset, so it is written once and right everywhere.

> [!TIP]
> Give the hero image on a landing page `loading="eager"`. It is the one image a visitor sees first, and lazy
> loading it only delays it.

Presets are named sizes in `config/nibble.yml`; `card`, `hero`, `content` and `og` exist out of the box. See
[Configuration](../running/configuration.md#5-image-presets).

## 3. Blocks

```vue
<Blocks :blocks="page.blocks" />
```

Each block is drawn by `views/sets/<set handle>.vue` with the set's fields as props. A set with no view renders
nothing. See [Views and layouts](views.md#5-blocks).

## 4. SEO and previews

Every layout starts with:

```vue
<SeoHead />
<PreviewBar />
```

Nibble writes a page's Open Graph and Twitter tags, its structured data and any verification tags into the HTML it
sends. `SeoHead` looks after the tags that change as a visitor moves between pages — the title, description,
canonical link and robots — so they stay right after the first page too. All of it comes from the entry's SEO
fields, falling back to its title, excerpt and featured image, and to the **SEO** global. See
[SEO, sitemaps and feeds](seo-and-feeds.md).

`PreviewBar` shows only when an editor is previewing a draft: a ribbon across the top corner, so nobody mistakes a
draft for the live page. It is also what lets Live Preview update the page in place as the editor types, keeping its
scroll position; a layout without it is reloaded on each change instead.

## 5. Pagination

```vue
<script setup lang="ts">
import { Pagination } from '@nibble'
import type { ViewProps } from '@site/types'
import PostCard from '../../components/PostCard.vue'

defineProps<ViewProps['posts/index']>()
</script>

<template>
  <PostCard v-for="post in posts.data" :key="post.id" :post="post" />
  <Pagination :meta="posts.meta" />
</template>
```

`Pagination` takes the `meta` of a [paginated query](queries.md#6-pagination) and links each page with the URL
parameter it declares — `param` if it is not `page`.

## 6. Forms

A form's definition comes from the view's sidecar (`from: form:demo`), and `useNibbleForm` does the rest: values,
posting, validation errors, the honeypot, the CAPTCHA and the success message.

```vue
<!-- site/themes/tidewater/components/DemoForm.vue -->
<script setup lang="ts">
import { useNibbleForm, type NibbleForm } from '@nibble'

const props = defineProps<{ form: NibbleForm }>()
const demo = useNibbleForm(props.form)
</script>

<template>
  <p v-if="demo.sent.value" role="status">{{ demo.message.value }}</p>
  <form v-else :action="form.action" method="post" novalidate @submit="demo.submit">
    <p v-if="demo.errors.value.base" role="alert">{{ demo.errors.value.base }}</p>

    <div v-for="field in form.fields" :key="field.handle">
      <label :for="field.handle">{{ field.display }}</label>
      <input :id="field.handle" v-model="demo.values[field.handle] as string" :name="demo.fieldName(field)" />
      <p v-if="demo.errors.value[field.handle]" role="alert">{{ demo.errors.value[field.handle] }}</p>
    </div>

    <button type="submit" :disabled="demo.processing.value">Book my demo</button>
  </form>
</template>
```

| From `useNibbleForm` | |
|---|---|
| `values` | a reactive map of field handle to value |
| `errors` | messages by field handle, and `base` for the form as a whole |
| `processing` | true while the submission is in flight |
| `sent`, `message` | whether it succeeded, and the success message |
| `submit`, `reset` | send it; clear it |
| `fieldName(field)` | the input `name` Nibble expects |
| `setFiles`, `accept` | for `files` fields |

> [!WARNING]
> This short example renders every field as a text input and leaves out the CAPTCHA widget, so it only works for a
> form without `captcha: true`. The theme you copied from `crumbs` has `components/ContactForm.vue`, which handles
> every public fieldtype, file uploads, the honeypot and the CAPTCHA. Start from it rather than from scratch.

## 7. Shared props

Every page receives the site's globals and menus. Read them anywhere, without threading props through:

```vue
<script setup lang="ts">
import { useGlobals, useNavigation, useSite } from '@nibble'

const site = useSite()
const company = useGlobals<{ name: string; tagline?: string }>('site')
const footer = useNavigation('footer')
</script>
```

| Composable | Returns |
|---|---|
| `useSite()` | the locale, the page's URL, its declared parameters, every global and every menu |
| `useGlobals(handle)` | one global's fields |
| `useNavigation(handle)` | one menu's links: `title`, `url`, `children` |
| `useLocale()` | the page's locale code |

All four return computed refs, so they stay current as a visitor navigates.

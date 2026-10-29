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
conditions, posting, validation errors, the honeypot, the CAPTCHA and the success message.

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
    <div v-if="Object.keys(demo.errors.value).length" :ref="(el) => (demo.summaryEl.value = el as HTMLElement)" role="alert" tabindex="-1">
      <p>{{ demo.errors.value.base ?? 'Please check these answers:' }}</p>
      <ul>
        <li v-for="error in demo.errorList.value" :key="error.handle">
          <a :href="error.href">{{ error.label }}: {{ error.message }}</a>
        </li>
      </ul>
    </div>

    <template v-for="field in form.fields" :key="field.handle">
      <div v-if="demo.isVisible(field)">
        <label :for="demo.inputId(field)">{{ field.display }}</label>
        <input
          :id="demo.inputId(field)"
          v-model="demo.values[field.handle] as string"
          :name="demo.fieldName(field)"
          :aria-describedby="demo.describedBy(field)"
          :aria-invalid="demo.errors.value[field.handle] ? 'true' : undefined"
        />
        <p v-if="field.instructions" :id="demo.helpId(field)">{{ field.instructions }}</p>
        <p v-if="demo.errors.value[field.handle]" :id="demo.errorId(field)">{{ demo.errors.value[field.handle] }}</p>
      </div>
    </template>

    <button type="submit" :disabled="demo.processing.value">Book my demo</button>
  </form>
</template>
```

A component written for one form can have its values typed. The generated `@site/types` has a type for each form,
named from its handle, with a field for each of its handles, and a view's `form:` query is typed with it, so
`useNibbleForm` knows the values without being told:

```vue
<script setup lang="ts">
import { useNibbleForm } from '@nibble'
import type { ViewProps } from '@site/types'

const props = defineProps<{ form: ViewProps['pages/contact']['contact'] }>()
const contact = useNibbleForm(props.form)
// contact.values.topic is 'sales' | 'support' | ''
</script>
```

Name the type yourself where the form comes from somewhere else: `useNibbleForm<ContactFormValues>(form)`, with
`ContactFormValues` from `@site/types`. `FormValues['contact']` is the same type by form handle. A select or radio
field is its option values, and `''` until something is chosen; checkboxes and a multiple select are arrays of them;
a toggle is a `boolean`, a `files` field is `File[]`, and an `integer` or `calculation` field is a string, a number or
`null`. A component that handles any form, taking a plain `NibbleForm`, gets values of `string`, `number`, `boolean`,
arrays or `null` and narrows them as before.

| From `useNibbleForm` | |
|---|---|
| `values` | a reactive map of field handle to value |
| `errors` | messages by field handle, and `base` for the form as a whole |
| `errorList` | the field errors in form order, each with `label`, `message` and an `href` to its input, for a summary at the top |
| `processing` | true while the submission is in flight |
| `sent`, `message` | whether it succeeded, and the success message |
| `submit`, `reset` | send it; clear it |
| `fieldName(field)` | the input `name` Nibble expects |
| `isVisible(field)` | whether the field's conditions hold for the current values |
| `inputId(field)`, `helpId(field)`, `errorId(field)` | the ids for a field's input, its help and its error, unique to the form |
| `describedBy(field)` | the `aria-describedby` for its input: the help id when the field has instructions or file limits, and the error id when it has an error |
| `summaryEl`, `messageEl` | refs for the error summary and the success message; each is focused when it appears, so give it `tabindex="-1"` |
| `setFiles`, `accept`, `fileLimits(field)` | for `files` fields; `fileLimits` describes the allowed types, size and count, such as "PDF or JPG, up to 5 MB each, at most 3 files." |
| `calculated(field)`, `calculatedText(field)` | for `calculation` fields: the current figure, or `null` while it's blank, and the figure as text in the site's locale with its `decimals`, `prepend` and `append`, such as "$1,350.00" (`""` while blank) |
| `enhanced` | true once the component has mounted in the browser, so a control that needs JavaScript can wait for it |
| `stepping`, `steps`, `step` | whether the form is showing one step at a time; its steps (sections with their `index`, leaving out any whose fields are all hidden); the position of the current one |
| `isCurrentStep(index)`, `isLastStep`, `progress` | whether section `index` is the one to draw; whether the current step is the last; how far along the visitor is, from 0 to 1 |
| `next`, `back` | check the current step with the server and move on, or stay with its errors; go back without a check |
| `stepEl` | a ref for the step heading, focused when the step changes, so give it `tabindex="-1"` and say which step it is |
| `saveForLater`, `saved` | save what was entered and email the visitor a link, for a form with `resume`; the message to show once it has |

Each field carries its settings, such as `placeholder`, `options`, and `prepend` and `append` to draw beside the
input, and an `integer` field's `min`, `max` and `step`. Text fields carry `autocomplete`, textareas `rows`, toggles `inline_label`,
dates `time_enabled`, `earliest_date` and `latest_date`, and selects `max_items` and `clearable`; `default` is already
resolved, so a computed default is a date, not a name. A field with a condition carries `conditions`, the rules for
when to draw it (see [Forms](../modelling/forms.md#1-declaring-a-form)). `isVisible(field)` evaluates them as the
server does, and `submit` leaves a field they hide out of what it posts; the server applies them again to what is
posted. A `custom` condition runs only on the server, so `isVisible` draws its field. A field with `hidden: true` is not drawn: it carries the `value` resolved for the current request (its `default`
is the same), and `form.action` already carries the prefilled query, so posting the form records it. After a failed post without JavaScript, `form.result` is `{ status: 'invalid', errors, values }`, where `values` are
the plain values the visitor typed, by field handle; `values` starts from them. A form split into sections also has `form.sections`, each with a `display`, `instructions` and the handles of
its `fields`; it is `null` for a form with one list. `form.captcha` has a `null` provider when the form asks for a
CAPTCHA the site hasn't set up. See [Forms](../modelling/forms.md).

A `calculation` field carries its `formula`, and its `decimals`, `prepend` and `append` when it has them.
`calculated(field)` runs the formula in the browser with the same rules as the server, over the current `values`, so it
changes as the visitor types; a field `isVisible` hides counts as 0. Draw it as read-only output, not an input, and let
screen readers hear it change:

```vue
<output :id="demo.inputId(field)" aria-live="polite">{{ demo.calculatedText(field) }}</output>
```

The form posts nothing for it: the server calculates the stored value itself (see
[Calculations](../modelling/forms.md#11-calculations)).

A form with `steps: true` has `form.steps` true. Until it mounts, `stepping` is false and `isCurrentStep` is true for
every section, so the server draws every step and a visitor without JavaScript fills in one long form. Once mounted,
draw only the section where `isCurrentStep(index)` holds, with `v-show` so a file a visitor chose stays chosen, and a
step heading on `stepEl` such as "Step 2 of 4". `submit` before the last step calls `next`, so the one submit button can
read Next until then, and a refused send opens the step with the first error. `next` sends a step only its own files.

A form with `resume: true` has `form.resume`, `{ email, days, token }`: the field that takes the visitor's address,
how many days the link works, and the token when the page was opened from a resume link (`?resume=<token>`). Then
`form.result` is `{ status: 'resumed', values }` and `values` starts from them, or `{ status: 'expired', message }`
when the link no longer works. `submit` sends the token as `_nibble_resume`, so the save is deleted once the form is
sent; a form posted without JavaScript needs it as a hidden input. Show `saved` in a `role="status"` element that is
on the page before it fills, so a screen reader announces it.

`NibbleFormField` is a union on `type`, so a template that checks `field.type === 'select'` reads `field.options`
without a cast.

> [!WARNING]
> This short example renders every field as a text input and leaves out the CAPTCHA widget, so it only works for a
> form without `captcha: true`. The theme you copied from `crumbs` has `components/ContactForm.vue`, which draws
> every public fieldtype with its own control (a checkbox for a toggle, a fieldset of radios or checkboxes for
> choices, a date or date-and-time input, a live `<output>` for a calculation), sends hidden fields, applies conditions,
> links help and errors to their inputs, handles file uploads, the honeypot and the CAPTCHA, and draws steps and Save
> and finish later. Start from it rather than from scratch.

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

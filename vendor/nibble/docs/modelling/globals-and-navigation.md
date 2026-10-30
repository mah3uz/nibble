---
id: modelling-globals-and-navigation
title: Globals and navigation
description: Site-wide fields every page can read, and the menus editors arrange — declared in YAML, read by the
  theme in one line.
order: 4
---

# Globals and navigation

Some content belongs to the whole site rather than to one page: Tidewater's name, its support address, the menu
across the top. Globals and navigation hold those.

After reading this guide, you will know:

- Which globals Nibble ships, and how to declare one of your own.
- How a rich-text link can follow an address kept in a global.
- How to declare a menu, limit what it can link to, and give its items fields of their own.
- How a menu can be built from a folder of files instead.
- How a theme reads both.

## 1. Globals

A global is one set of fields for the whole site — not a page, not a list. Nibble ships three:

| Global | Holds |
|---|---|
| `site` | the site's name, tagline, logo, favicon, contact address and social links |
| `seo` | the title template, default description and share image, and verification tags |
| `integrations` | [analytics tools and custom code](../editing/analytics.md), CAPTCHA keys, and who mail comes from |

Editors fill them in under **Globals**.

![The Site global, with Tidewater's name and tagline](../../images/cp/globals.png)

### 1.1 A global of your own

Tidewater shows its company details in the footer and on invoices' help pages. Generate a global:

```sh
bin/rails nibble:generate:global company
```

and give it fields. A global's blueprint is written inline:

```yaml
# site/schema/globals/company.yml
schema: 1
title: Company
blueprint:
  title: Company
  tabs:
    main:
      sections:
        - fields:
            - handle: legal_name
              field: { type: text, required: true }
            - handle: address
              field: { type: textarea }
            - handle: support_email
              field: { type: text, input_type: email }
```

Add `localizable: true` when the values differ per language.

> [!WARNING]
> Globals are the wrong place for secrets. Every page receives every global except `integrations` — which Nibble
> keeps out of the page because it holds keys — so anything in your own global can end up in a visitor's browser.
> API keys belong in [credentials or the environment](../running/configuration.md#6-environment-and-credentials).

### 1.2 Linking to a global from rich text

An address used on many pages — the application form, the booking page — can live in one global field, and every
rich-text link to it follows that field. Give the global a field that holds an address: a `text` field with
`input_type: url`, or a `link` field.

```yaml
            - handle: apply_url
              field: { type: text, input_type: url }
```

In the rich-text link dialog, choose **Site settings**, then the group and the field. The dialog shows the address the
field holds now. When someone changes the field, every page that links to it shows the new address, without its
entries being saved again.

The link keeps the address it had when the entry was saved beside its reference, `global:site.apply_url`, so an
export carries a working link. When the page renders, the field's current value is checked like any other link: if
it is empty or isn't a web, email, phone or on-site address, the words show without a link. A link reads the global
in the site's default language. Saving refuses a link to a global or field that doesn't exist, and so does a
package import; a link whose field is later taken out of the schema shows the address it was saved with.

Apps writing Markdown through the [management API](../extending/management-api.md) write the same link as
`[Apply](global:site.apply_url)`, and read it back that way.

## 2. Navigation

A navigation is a menu: a tree of links editors arrange by dragging. Nibble ships `main` and `footer`.

```yaml
# site/schema/navigation/main.yml
schema: 1
title: Main
max_depth: 2
collections: [pages, posts]
```

| Key | What it does |
|---|---|
| `title` | **required**; what the Control Plane calls it |
| `max_depth` | how deep items may nest — a header with dropdowns wants `2`; without it, items nest without limit |
| `collections`, `taxonomies` | the entries and terms an item may link to |
| `globals` | `true`, or a list of global handles: the global fields holding an address that an item may link to |
| `assets` | `true` lets an item link to a file in the media library |
| `headings` | `true` lets an item be a heading, with a title and no link |
| `item_fields` | fields every item has, written like a blueprint's |
| `entry_fields` | fields of a linked entry the theme receives with the item |

A typed URL is always allowed. A menu that declares none of the keys from `globals` down holds links only, as it
always has.

Tidewater's main menu links to the Pricing and Book a demo pages, and to `/blog` and `/help` by URL.

![Tidewater's main menu in the navigation editor](../../images/cp/navigation.png)

> [!TIP]
> Link to an entry rather than typing its URL whenever you can. If the page's slug changes or it moves under
> another page, an entry link follows it; a typed URL has to be found and fixed by hand.

### 2.1 Items: links and headings

An item is a link, or a heading when the menu has `headings: true`. A link points at one of:

| Target | Stored as | Its address |
|---|---|---|
| an entry or a term | its id | the record's current path, so it follows renames and moves |
| a typed URL | the URL | as typed; only web, email, phone and on-site addresses are accepted |
| a global field | `global:<handle>.<field>`, such as `global:site.apply_url` | whatever the field holds now, as [rich-text links](#12-linking-to-a-global-from-rich-text) read it |
| a file | its id | the file's public address |

A link to an entry, a term or a file uses the record's title unless the item has its own; a typed URL and a global
field need a title. A link whose target is deleted, or whose global field holds no safe address, is left out of the
menu until it has one again.

A heading groups the items under it, such as the columns of a footer. It has a title and children, and no link.

Any item can be marked **Open in a new tab** or **Hidden**. A hidden item and everything under it never reach the
theme, so an editor can park one without deleting it.

### 2.2 Item fields and entry fields

`item_fields` gives every item of a menu fields of its own, validated and shaped like an entry's:

```yaml
# site/schema/navigation/main.yml
schema: 1
title: Main
max_depth: 2
collections: [pages, posts]
headings: true
globals: [site]
item_fields:
  - handle: description
    field: { type: text, validate: [ "max:80" ] }
  - handle: highlight
    field: { type: toggle }
entry_fields: [icon]
```

`entry_fields` names fields of the linked entries that the theme receives with the item, such as an icon a page
already has, so editors don't type it twice. Only the fields listed are sent. `bin/rails nibble:check` reports an item
field it can't build and an entry field no blueprint of the menu's collections has.

### 2.3 A menu built from files

When a navigation has the same handle as a [collection written as files](content-as-files.md), its tree is built
from the folders instead: a folder's `index.md` is a branch, the files in it are its children, and `order` in their
frontmatter sorts them. That is Tidewater's help centre sidebar:

```yaml
# site/schema/navigation/help.yml
schema: 1
title: Help centre
max_depth: 3
```

> [!WARNING]
> A menu built from files still appears under **Navigation** in the Control Plane, as an empty menu with
> **Add link** and **Save**. Anything saved there is ignored — the site always reads the folders. Change the files
> instead.

## 3. Reading them in a theme

Every page receives every global except `integrations`, and every navigation, so a component anywhere can read
them without props being passed down:

```vue
<script setup lang="ts">
import { useGlobals, useNavigation } from '@nibble'

const site = useGlobals<{ name: string; contact_email?: string }>('site')
const main = useNavigation('main')
</script>

<template>
  <header>
    <a href="/">{{ site.name }}</a>
    <nav>
      <a v-for="link in main" :key="link.url" :href="link.url">{{ link.title }}</a>
    </nav>
  </header>
</template>
```

Each item has a `title`, a `url` and `children`, which is always a list — so a nested menu is the same loop one level
down, whether the menu was arranged by an editor or built from files. It also has:

| Key | Value |
|---|---|
| `kind` | `link`, or `heading`, whose `url` is `null` |
| `new_tab` | whether the editor asked for a new tab |
| `current` | the item's address is the page being shown |
| `in_trail` | the item is current, one of its children is in the trail, or the page is under the item's path |
| `fields` | the item's `item_fields` |
| `entry` | the linked entry's `entry_fields`, or `null` |

`current` and `in_trail` are worked out for each page from its path, ignoring a trailing slash and a query string.
`/` is only ever current on the home page, never in the trail of another; a link to another site, an email address
or a phone number, or a link with a `#` fragment, is never current.

```vue
<template>
  <nav>
    <template v-for="item in main" :key="item.title">
      <span v-if="item.kind === 'heading'">{{ item.title }}</span>
      <a v-else :href="item.url" :aria-current="item.current ? 'page' : undefined"
         :class="{ active: item.in_trail }" :target="item.new_tab ? '_blank' : undefined"
         :rel="item.new_tab ? 'noopener' : undefined">
        {{ item.title }}<span v-if="item.new_tab" class="sr-only"> (opens in a new tab)</span>
      </a>
    </template>
  </nav>
</template>
```

A link that opens a new tab should say so, as the hidden text above does, for people who can't see the page. See
[Theme components](../theming/components.md).

> [!NOTE]
> A page's cache is tagged with the globals and menus it read, and with the records, files and globals a menu links
> to, so editing the footer, or the global field a menu item follows, clears every cached page that shows it — and
> only those pages are re-rendered.

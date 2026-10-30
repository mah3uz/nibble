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
- How a menu can hold items of your own kind, list a collection's pages by itself, or show an item only for a while.
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
| `kinds` | kinds of item of your own, each with a `display` name, a `link` rule, `children` and `fields`; see [2.3](#23-kinds-of-your-own) |
| `queries` | collections an item may list by itself; see [2.4](#24-items-that-list-a-collection) |

A typed URL is always allowed. A menu that declares none of the keys from `globals` down holds links only, as it
always has. Every item, of any kind, can also be given a [window in which it shows](#25-showing-an-item-for-a-while).

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

### 2.3 Kinds of your own

`kinds` adds kinds of item beside `link` and `heading`. Tidewater's header has a "Featured" item: a card with an image
and a line of text that sits in a dropdown and links nowhere by itself.

```yaml
# site/schema/navigation/main.yml
kinds:
  featured:
    display: Featured
    link: optional
    children: false
    fields:
      - handle: image
        field: { type: asset }
      - handle: blurb
        field: { type: text }
```

| Key | What it does |
|---|---|
| `display` | what the Control Plane calls the kind; defaults to the handle, capitalised |
| `link` | `optional` (the default) lets the item link, or not; `required` makes it link; `none` forbids a link |
| `children` | `false` stops the item holding items under it; defaults to `true` |
| `fields` | fields only this kind has, written like `item_fields` |

The menu's `item_fields` apply to a custom kind too. The kind's own `fields` come after them, and win a handle both
declare. `link`, `heading` and `query` are built in and can't be redefined here.

An editor picks the kind when adding an item. An item of a kind the menu doesn't list, or one that breaks its `link`
or `children` rule, is rejected on save.

### 2.4 Items that list a collection

`queries` lists the collections an item may list by itself. Tidewater's header has a "Latest from the blog" dropdown
that should always show the newest posts, without an editor adding each one.

```yaml
# site/schema/navigation/main.yml
queries: [posts, pages]
```

An item of kind `query` has a title and no link, and its items aren't added by hand. The editor chooses:

| Setting | What it does |
|---|---|
| collection | which of the menu's `queries` it lists; a collection written as files can't be listed |
| parent page | only the pages directly under this page |
| term | only the pages tagged with this term; the collection needs a field for that taxonomy |
| sort | `field:asc` or `field:desc`, as in a [query's `sort`](../theming/queries.md); without it, the collection's own order |
| limit | how many to list, from 1 to 50; 50 without it |

The children are filled in on the site, when the page is rendered. They are the collection's published entries in the
page's locale, each a plain `link`, so a page published tomorrow appears in the menu without anyone editing it.

> [!WARNING]
> A query item makes every page that shows the menu depend on the whole collection. Any change to that collection
> (publishing, editing or trashing one entry) clears each of those cached pages, which is usually every
> page on the site. That is fine for a collection of a few hundred pages edited now and then. On a big or busy one,
> such as a blog or a collection that is imported often, list a few pages by hand, or link the menu to an index page
> that lists the collection, instead.

### 2.5 Showing an item for a while

Any item can be given **Show from** and **Show until** dates. Outside that window the item, and everything under it,
is absent from the menu the theme reads. A window with no start shows until its end; one with no end shows from its
start. Until must come after from.

Tidewater's header can carry a "Summer sale" link that appears on the 1st of December and goes on the 1st of January.
Cached pages are refreshed at each date, a few seconds after it, so the menu changes without anyone saving. That relies
on the job runner (Solid Queue) running, as [Deploying](../running/deploying.md) describes; where it doesn't run, a
page already cached keeps showing the old menu until something else clears it.

Through the [management API](../extending/management-api.md) the dates are `show_from` and `show_until` on the item,
written like `2026-12-01T09:00:00+10:00`.

### 2.6 A mega-menu

Tidewater's header puts these together: a Products column with a heading, two pages and a featured card, and the
newest posts.

```yaml
# site/schema/navigation/main.yml
schema: 1
title: Main
max_depth: 3
collections: [pages, posts]
headings: true
queries: [posts]
item_fields:
  - handle: icon
    field: { type: text }
kinds:
  featured:
    display: Featured
    link: optional
    children: false
    fields:
      - handle: image
        field: { type: asset }
      - handle: blurb
        field: { type: text }
```

An editor builds the tree in the Control Plane: a heading **Products**, under it links to Pricing and Book a demo and a
Featured item, and beside it a **Latest from the blog** query item listing `posts` with a limit of 3.

### 2.7 A menu built from files

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
| `kind` | `link`; `heading`, or `query`, whose `url` is `null`; or a kind of your own |
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

Narrow on `kind` when a menu has more than one. A `query` item has a title and no url, and its `children` are links
to the pages it lists. A custom kind carries its own `fields`, and its `url` is `null` when it has no link. For Tidewater's
header above:

```vue
<script setup lang="ts">
import { useNavigation } from '@nibble'

const main = useNavigation('main')
</script>

<template>
  <nav>
    <div v-for="item in main" :key="item.title">
      <template v-if="item.kind === 'heading'">
        <strong>{{ item.title }}</strong>
        <template v-for="child in item.children" :key="child.title">
          <figure v-if="child.kind === 'featured'">
            <img :src="child.fields.image?.url" :alt="child.fields.image?.alt ?? ''" />
            <figcaption>
              <a v-if="child.url" :href="child.url">{{ child.title }}</a>
              <span v-else>{{ child.title }}</span>
              {{ child.fields.blurb }}
            </figcaption>
          </figure>
          <a v-else :href="child.url ?? undefined">{{ child.title }}</a>
        </template>
      </template>
      <template v-else-if="item.kind === 'query'">
        <strong>{{ item.title }}</strong>
        <a v-for="post in item.children" :key="post.url" :href="post.url ?? undefined">{{ post.title }}</a>
      </template>
      <a v-else :href="item.url ?? undefined">{{ item.title }}</a>
    </div>
  </nav>
</template>
```

A link that opens a new tab should say so, as the hidden text above does, for people who can't see the page. See
[Theme components](../theming/components.md).

> [!NOTE]
> A page's cache is tagged with the globals and menus it read, and with the records, files and globals a menu links
> to, so editing the footer, or the global field a menu item follows, clears every cached page that shows it — and
> only those pages are re-rendered.

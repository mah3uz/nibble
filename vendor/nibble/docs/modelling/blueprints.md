---
id: modelling-blueprints
title: Blueprints and fields
description: The form an editor fills in and the shape stored data is checked against — tabs, sections, every
  fieldtype, blocks, fieldsets and conditional fields.
order: 2
---

# Blueprints and fields

A blueprint is two things at once: **the form an editor fills in**, and **the shape the stored data is checked
against**. This guide builds the blueprints behind Tidewater's landing pages and blog.

After reading this guide, you will know:

- How a blueprint is laid out in tabs, sections and fields.
- The options every field accepts, and every fieldtype Nibble ships.
- How to build pages from blocks with a replicator.
- How to share fields between blueprints with fieldsets.
- How to show a field only when another has a certain value.
- How blueprints become TypeScript types for your theme.

## 1. Anatomy of a blueprint

Tidewater's customer stories need a quote, the customer's logo and an industry:

```yaml
# site/schema/blueprints/collections/customers/story.yml
schema: 1
title: Customer story
tabs:
  main:
    display: Content
    sections:
      - display: The story
        instructions: What changed for the customer, in their words.
        fields:
          - handle: title
            field: { type: text, required: true, listable: true }
          - handle: quote
            field: { type: textarea, required: true, character_limit: 280 }
          - handle: body
            field: { type: rich_text }
  details:
    display: Details
    sections:
      - fields:
          - handle: logo
            field: { type: assets, max_files: 1, alt: required, width: 50 }
          - handle: industry
            field: { type: terms, taxonomies: [industries], max_items: 1, width: 50 }
  seo:
    display: SEO
    sections:
      - fields:
          - import: nibble::seo
```

- **Tabs** group the form. The editor sees Content, Details and SEO across the top.
- **Sections** group fields within a tab, and can carry a heading and an instruction line.
- **Fields** each have a `handle` — the name the value is stored under, and what your views use — and a `field`
  describing its type and options.

A blueprint lives at `blueprints/collections/<collection>/<handle>.yml`, or `blueprints/taxonomies/<taxonomy>/…` for
terms. The collection lists which blueprints it allows; the first is the default.

![A page open in the editor: its fields and a pricing block, with the slug, parent, author and template in the column on the right](../../images/cp/page-editor.png)

## 2. Options every field takes

| Option | What it does |
|---|---|
| `display` | the label; defaults to the handle, humanised |
| `instructions` | help text, shown below the label — `instructions_position: below` moves it under the input |
| `required` | a value is needed to save; a `toggle` must be switched on. Takes `true`, `false`, or [a condition](#6-conditional-fields) that says when |
| `validate` | extra rules, such as `[max:200]` or `["required_with:{this}.button_label"]` |
| `messages` | what to say when a rule fails, keyed by rule name — see below |
| `default` | the value a new entry, term, global or row starts with; entries that already exist keep what they have, and [`set_default`](changing-schema.md#42-set_default) fills them |
| `width` | how much of the row it takes: `25`, `33`, `50`, `66`, `75` or `100` |
| `localizable` | the value differs per locale |
| `listable` | `true` shows it as a column in the listing, `hidden` offers it in the column picker, `false` never |
| `read_only` | shown but not editable, and kept as it is on every save — see below; `{ if: … }` makes it read-only while a condition passes |
| `visibility` | `visible`, `read_only`, `hidden` or `computed` |
| `api` | `false` leaves the field out of the generated TypeScript types and the Content API; a page still receives it |

The [field reference](../reference/fieldtypes.md#options-every-field-takes) lists these and the rest, such as `width`
and `always_save`, with their defaults. The notes below cover the ones that need explaining.

A `default` of `computed:<name>` is worked out each time it is used. Nibble has one built in, `computed:today`, the
current date in the site's time zone as `YYYY-MM-DD`. A site registers its own in an initializer, and `nibble:check`
reports a `computed:` default nothing has registered:

```ruby
Nibble::Defaults.register("quarter") { "Q#{(Time.zone.today.month - 1) / 3 + 1}" }
```

A `required` toggle has to be switched on: an entry can't be published, and a term or global set can't be saved, while
it is off. A toggle that may be left off is not required. The `accepted` rule (`validate: [accepted]`) asks the same of
any field, taking `true`, `1`, `"1"`, `"yes"`, `"on"` and `"true"`, and says "Terms must be accepted."
`nibble:check` warns, per collection, taxonomy and global set, how many records hold a required toggle that is off, so
they can be switched on, or the field made optional, before someone next saves them.

A read-only field (`read_only: true` or `visibility: read_only`) keeps what it holds whoever saves: an editor in the
Control Plane, a token on the management API or an app over MCP. Anything they send for it is ignored and the rest of
the save goes through. A new entry, term, global set or row starts it from its `default`, or empty. Only Nibble itself
changes it: package imports, content migrations and scheduled tasks. Restoring a revision leaves it as it is, the
bulk Assign terms action refuses a read-only terms field, and replacing an asset everywhere from the media library
replaces it in read-only fields too. In a grid or replicator, a row keeps its read-only
values by its `id`, so moving a row moves them with it; a row sent without a stored `id` is a new row, and a removed
row's values go with it.

`read_only` can instead hold one condition, written as a [conditional field](#6-conditional-fields)'s is, which makes
the field read-only while it passes on the values being saved:

```yaml
- handle: locked
  field: { type: toggle }
- handle: reference
  field: { type: text, read_only: { if: { locked: true } } }
```

`nibble:check` refuses a `read_only` that isn't `true`, `false` or a map with exactly one of `if`, `if_any`, `unless`,
`unless_any`, `show_when`, `show_when_any`, `hide_when` or `hide_when_any`.

A failed rule says "Phone isn't in the expected format." unless the field gives its own wording. `messages` is keyed by
the name of a rule the field has (an `integer` field with a `step` also has `step`, which a form enforces), and each value is a string or a map of locale code to string:

```yaml
field:
  type: text
  validate: ["regex:/^04\\d{8}$/", "min:2"]
  messages:
    regex: Enter an Australian mobile number
    min:
      en: At least %{min} characters
      fr: Au moins %{min} caractères
```

A rule's message is used in the locale of the record or submission, then the site's default locale, then Nibble's own
wording. It takes the same placeholders as the default (`%{attribute}`, `%{min}`, `%{max}`…), and `min`, `max`,
`between` and `size` cover the number, text and list variants alike. Editors in the Control Plane, visitors on a form
and connected apps see it. `nibble:check` refuses a message for a rule the field doesn't have, a value that isn't text,
and a locale the site doesn't have.

## 3. The fieldtypes

Every fieldtype, what it stores and each option it takes is listed in the
[fieldtype reference](../reference/fieldtypes.md).

| Group | Types |
|---|---|
| Text | [`text`](../reference/fieldtypes.md#text), [`textarea`](../reference/fieldtypes.md#textarea), [`code`](../reference/fieldtypes.md#code), [`rich_text`](../reference/fieldtypes.md#rich_text), [`markdown`](../reference/fieldtypes.md#markdown), [`slug`](../reference/fieldtypes.md#slug), [`secret`](../reference/fieldtypes.md#secret) |
| Numbers and dates | [`integer`](../reference/fieldtypes.md#integer), [`decimal`](../reference/fieldtypes.md#decimal), [`range`](../reference/fieldtypes.md#range), [`rating`](../reference/fieldtypes.md#rating), [`date`](../reference/fieldtypes.md#date), [`time`](../reference/fieldtypes.md#time), [`calculation`](../reference/fieldtypes.md#calculation) |
| Choice | [`select`](../reference/fieldtypes.md#select), [`radio`](../reference/fieldtypes.md#radio), [`button_group`](../reference/fieldtypes.md#button_group), [`checkboxes`](../reference/fieldtypes.md#checkboxes), [`toggle`](../reference/fieldtypes.md#toggle), [`list`](../reference/fieldtypes.md#list), [`color`](../reference/fieldtypes.md#color) |
| Relationships | [`entries`](../reference/fieldtypes.md#entries), [`terms`](../reference/fieldtypes.md#terms), [`link`](../reference/fieldtypes.md#link) |
| Files | [`assets`](../reference/fieldtypes.md#assets), [`files`](../reference/fieldtypes.md#files) |
| Repeating | [`grid`](../reference/fieldtypes.md#grid), [`replicator`](../reference/fieldtypes.md#replicator) |
| Whole page | [`seo`](../reference/fieldtypes.md#seo) |
| Display only | [`note`](../reference/fieldtypes.md#note) |

A few choices come up in nearly every blueprint:

- **Text.** `text` is one line; `textarea` is several; `rich_text` is the full editor, stored as structured data and
  rendered to safe HTML on the server, so a theme never receives markup it has to trust. `markdown` is for text an
  editor would rather write as Markdown. An `input_type` of `email`, `url` or `tel` on a `text` field also checks the
  value; see [`text`](../reference/fieldtypes.md#text).
- **Pictures and files.** `assets` opens the media library. `max_files: 1` makes it a single image, `alt: required`
  insists on alt text, and `preset: hero` names the [image size](../running/configuration.md#5-image-presets) your
  theme receives. `files` is for visitors' uploads on a [public form](forms.md).
- **Choosing from a fixed list.** `select`, `radio`, `button_group` and `checkboxes` hold a list written in the
  blueprint. For a list your editors manage themselves, use a taxonomy with a `terms` field, or an `entries` field,
  instead of options.
- **Relationships.** `entries` and `terms` open a picker and store a reference, not a copy: rename or move the target
  and the reference still finds it. `max_items: 1` makes a single choice. `link` accepts a URL or a link to an entry
  and follows the entry if it moves.
- **Numbers.** `integer` and `decimal` take `min` and `max`; `decimal` keeps a fixed number of places, such as a price.
- **Repeating.** `grid` is a table of rows with the same fields, such as opening hours or a price list. `replicator`
  is a list of blocks, each a different shape; it is how landing pages are built, in the next section.

## 4. Pages built from blocks

Tidewater's marketing pages are a stack of blocks that marketing chooses and orders themselves. A replicator declares the
**sets** — the kinds of block — grouped into menus:

```yaml
- handle: blocks
  field:
    type: replicator
    display: Page blocks
    button_label: Add block
    sets:
      content:
        display: Content
        sets:
          rich_text:
            display: Text
            icon: text
            fields:
              - handle: text
                field: { type: rich_text, required: true }
          pricing:
            display: Pricing
            icon: layout-grid
            fields:
              - handle: plans
                field:
                  type: grid
                  add_row: Add plan
                  fields:
                    - handle: name
                      field: { type: text, required: true }
                    - handle: price
                      field: { type: text, required: true }
                    - handle: features
                      field: { type: list }
```

A set can also carry:

| Key | What it does |
|---|---|
| `instructions` | one line under the set's name in the menu |
| `icon` | a Control Plane icon beside its name |
| `badge` | a short label on the menu entry and on each block's header, such as `Needs consent` |
| `max` | how many of this set the field may hold; the menu hides it once that many exist |

On the field, `max_sets` caps the blocks of every set together, and `tab_count: true` shows how many are switched on
beside the tab's name. `button_position: header` puts the Add button in the header of the section the field is in,
and `insert_below: false` leaves out the button on each block that adds another beneath it, for a list whose order
matters less than its contents. `collapse: true` opens the editor with every block folded to its header, and
`collapse: accordion` does the same and keeps one block open at a time.

Each set is drawn by `views/sets/<set handle>.vue` in the theme, which receives the set's fields as props. The
[Getting Started](../getting-started/tutorial.md#42-a-block-of-your-own-pricing) guide builds the pricing block end
to end, and [Theme components](../theming/components.md) covers the `Blocks` component that renders them.

> [!TIP]
> Nibble ships a standard set of blocks — text, quote, call to action, image, gallery and embed — as
> `nibble::page_fields.blocks`. Reference it with `field: nibble::page_fields.blocks` when you need nothing more.
> To change the list without copying it, add `add_sets` and `remove_sets` under `config`:
>
> ```yaml
> - handle: blocks
>   field: nibble::page_fields.blocks
>   config:
>     add_sets:
>       content:                 # an existing group: the set goes at its end
>         latest_posts:
>           display: Latest posts
>           fields:
>             - handle: count
>               field: { type: integer, min: 1, max: 12, default: 3 }
>       showcase:                # a new group: it goes after the existing ones
>         display: Showcase
>         sets:
>           logos:
>             display: Logos
>             fields:
>               - handle: images
>                 field: { type: assets }
>     remove_sets: [embed]
> ```
>
> `nibble:check` refuses an added handle the field already has (replace a set with `config: sets` instead, or pick
> another handle), a removed set the field doesn't have, and a removed set that saved blocks still use. Every other
> key under `config` replaces the field's own, as for any reference. `add_sets` and `remove_sets` work on any
> replicator reached through a reference.

> [!CAUTION]
> Removing a set that pages already use strands the blocks written with it. `nibble:check` refuses the change and
> names the pages; move their content first, or keep the set.

## 5. Fieldsets: fields written once

A fieldset is a list of fields several blueprints import. Nibble ships four:

| Fieldset | Fields |
|---|---|
| `nibble::seo` | the SEO title, description, share image, canonical URL, `noindex` and sitemap switches |
| `nibble::page_fields` | a title and the standard blocks |
| `nibble::post_fields` | a title, an excerpt and a body |
| `nibble::featured_image` | one image |

Import a whole fieldset, or one field of it:

```yaml
- import: nibble::seo
- handle: blocks
  field: nibble::page_fields.blocks
```

Tidewater's call-to-action fields appear on pages, posts and customer stories, so they are a fieldset of its own:

```sh
bin/rails nibble:generate:fieldset cta
```

```yaml
# site/schema/fieldsets/cta.yml
title: Call to action
fields:
  - handle: cta_heading
    field: { type: text }
  - handle: cta_link
    field: { type: link }
```

and each blueprint says `- import: cta`. Change the fieldset and every blueprint using it changes with it.

## 6. Conditional fields

A field can appear only when another has a certain value. Tidewater's page hero is either an image or a video:

```yaml
- handle: hero_kind
  field:
    type: radio
    options: { image: Image, video: Video }
    default: image
- handle: hero_image
  field: { type: assets, max_files: 1, if: { hero_kind: image } }
- handle: hero_video_url
  field: { type: text, input_type: url, if: { hero_kind: video } }
```

The form shows and hides them as the editor works, and validation follows: a hidden field is never required. The keys
are `if`, `unless`, `show_when` and `hide_when`, and each has an `_any` form — `if_any` — that passes when any one rule
matches rather than all of them.

A rule can compare as well as match: `employees: ">= 10"`, `extras: contains delivery`, `notes: not empty`. A field can
name one outside its own row with `$root.` or `$parent.`, and `required` and `read_only` take a condition too.
`required: { if: { contact_by: phone } }` makes a field required only while the condition passes. A condition never
removes a hidden field's value; `always_save: true` keeps its rules running while it is hidden. The
[conditions reference](../reference/conditions.md) has the full syntax, every operator, custom conditions and what a
hidden field keeps.

## 7. Generated types

Every blueprint becomes a TypeScript type in `site/types.d.ts`, named after the collection and
blueprint: `PostsPost`, `PagesPage`, `HelpArticle`. Your views import them:

```ts
import type { ViewProps, PostsPost } from '@site/types'
```

so `page.excerpt` is known to exist and a typo fails `vue-tsc` rather than a visitor's page.

Each collection also gets a union of its blueprints, `PostsEntry`, and each taxonomy one of its blueprints,
`TopicsTerm`, for a view that takes any of them. Where that name is already a blueprint's, the union is left out.

> [!IMPORTANT]
> The types are regenerated by the generators and by `bin/rails nibble:schema:types`. Edit a blueprint by hand
> and `nibble:check` reports the types as out of date until you run it — which is what stops a view using a field
> that no longer exists from reaching production.

## 8. What's next

- [Taxonomies](taxonomies.md) — the authors and topics a post relates to.
- [Changing the schema](changing-schema.md) — renaming or removing a field once content uses it.

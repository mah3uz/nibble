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
| `api` | `false` leaves the field out of the generated TypeScript types — the value is still sent to pages and the API |

A `required` toggle has to be switched on: an entry can't be published, and a term or global set can't be saved, while
it is off. A toggle that may be left off is not required. The `accepted` rule (`validate: [accepted]`) asks the same of
any field, taking `true`, `1`, `"1"`, `"yes"`, `"on"` and `"true"`, and says "The Terms field must be accepted."
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

A failed rule says "The Phone field format is invalid." unless the field gives its own wording. `messages` is keyed by
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

| Group | Types |
|---|---|
| Text | `text`, `textarea`, `code`, `rich_text`, `markdown`, `slug`, `secret` |
| Numbers and dates | `integer`, `decimal`, `range`, `rating`, `date` |
| Choice | `select`, `radio`, `checkboxes`, `toggle`, `list` |
| Relationships | `entries`, `terms`, `relationship`, `link` |
| Files | `assets`, `files` |
| Repeating | `grid`, `replicator` |
| Whole page | `seo` |
| Display only | `note` |

The ones worth knowing properly:

**`text`** takes an `input_type`: `text` (the default), `email`, `url`, `tel`, `number`, `date`, `month`, `week`,
`time`, `color`, `password` or `hidden`, which sets the input a theme draws. Three of them check the value when it is
saved, in a blueprint and on a [public form](forms.md) alike, and a blank value always passes:

| `input_type` | Accepts | Message key |
|---|---|---|
| `email` | an email address | `email` |
| `url` | an absolute `http://` or `https://` address | `url` |
| `tel` | digits, spaces and `+ ( ) . -`, with at least three digits | `phone` |

A field's own `validate: [ "regex:/^04\d{8}$/" ]` replaces the phone check, so a site can ask for the numbers it
takes. Each rule's wording comes from the field's `messages` under the key above, per locale if the site has several
(see [Options every field takes](#2-options-every-field-takes)). `nibble:check` warns when saved entries, terms or
global sets hold an email, URL or phone that fails its check, with how many and the first few ids; they can't be saved
again until the value is corrected. The other options of a `text` field are `character_limit`, `autocomplete`,
`placeholder`, `prepend` and `append`.

**`toggle`** is a switch; its `inline_label` is the text beside it, and `inline_label_when_true` replaces that text
while it is on. `inline_label` may hold Markdown links, such as `I agree to the [privacy policy](/privacy)`, per
locale like any label. A link may go to a web, email or phone address or a page on the site; anything else, such as
`javascript:`, is shown as plain text. Nothing else in the label becomes markup. See the
[consent checkbox recipe](forms.md#13-a-consent-checkbox).

**`note`** shows text and holds no value. Its `text` is Markdown, per locale if the site has several: paragraphs,
emphasis, lists and links to web, email, phone or site addresses are kept, and everything else, including raw HTML,
headings and images, is dropped. The Control Plane draws it as a muted block across the form, and a public form passes
it to the theme as `text_html`. A note is never stored, exported, emailed, searched, listed in the content API, or
offered to connected apps to write. It can't be `required`, `hidden`, `encrypt`ed or have a `default`; `nibble:check`
refuses those.

```yaml
- handle: pricing_hint
  field:
    type: note
    text: |
      Prices include **GST**. See the [price list](/prices) for what is covered.
```

**`rich_text`** is the full editor — headings, lists, links, images, tables, code blocks and find-and-replace. It is
stored as structured data, not HTML, and rendered to safe HTML on the server. Your theme never sees raw markup it
has to trust. A link can point at a [global field](globals-and-navigation.md#12-linking-to-a-global-from-rich-text)
instead of an address, and follows that field when it changes.

**`markdown`** is a textarea with a Preview button, rendered by the server exactly as your theme will receive it.
Turn on `sanitize` when the text could come from someone you do not trust.

**`assets`** opens the media library. `max_files: 1` makes it a single image, `alt: required` insists on alt text,
and `preset: hero` names the [image size](../running/configuration.md#5-image-presets) your theme receives.

**`entries`** and **`terms`** open a picker and store a reference, not a copy — rename or move the target and the
reference still finds it. `max_items: 1` makes a single choice.

**`integer`** is a whole number. It takes `min`, `max`, `step`, `placeholder`, and `prepend` and `append`, text the input
shows before and after the number.

**`decimal`** is a number with a fixed number of places, such as a price. `decimals` (0 to 10, default 2) is how many
places it keeps: a value is rounded half away from zero to that many places when it is saved, so `2.675` is stored as
`2.68` and `-2.675` as `-2.68`. It is always stored as a number, never a string. `min` and `max` refuse a value outside
them. `step` is what the input moves by (default the smallest step `decimals` allows, such as `0.01`); it is a hint to the
input, not a rule. `placeholder`, `prepend` and `append` work as they do on `integer`. A form's submission list, emails and export show
the value with exactly `decimals` places.

**`range`** is a slider that stores a number, shown beside the slider as it moves. `min` (default 0), `max` (default 100)
and `step` (default 1) set the scale, `prepend` and `append` are drawn around the value, and `default` is where it starts.
The value is stored as a whole number when `min`, `max` and `step` are all whole, and as a decimal otherwise. A value
outside `min` and `max` is refused.

**`rating`** is a row of stars. `max` (2 to 10, default 5) is how many. It stores a whole number from 1 to `max`, or nothing
when it has not been rated; an editor clears it by choosing the same star again. A value outside 1 to `max` is refused.
Arrow keys move between the stars, and each star is named for a screen reader, such as "3 of 5".

**`select`**, **`radio`** and **`checkboxes`** hold a fixed list written in the blueprint. For a list your editors
manage themselves, use a taxonomy with a `terms` field, or an `entries` field with `mode: select`, instead of
options.

**`link`** accepts a URL or a link to an entry, and follows the entry if it moves.

**`code`** is an editor for HTML, with line numbers and highlighting, for snippets pasted from another tool.

**`secret`** stores its value encrypted, and never shows it again in full — for an API key a site setting needs.

**`grid`** is a table of rows with the same fields — opening hours, a price list.

**`replicator`** is a list of blocks, each a different shape. It is how landing pages are built.

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
> When you do, copy it into your blueprint and add to it.

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

The form shows and hides them as the editor works, and validation follows: a hidden field is never required. The
keys are `if`, `unless`, `show_when` and `hide_when`, and each has an `_any` form — `if_any` — that passes when any
one condition matches rather than all of them.

### Required only sometimes

`required` takes a condition in place of `true`: exactly one of those keys, with the rules a field uses to show itself.
The field is required while the condition passes against the values being saved, and optional while it fails:

```yaml
- handle: contact_by
  field: { type: radio, options: { phone: Phone, email: Email }, default: email }
- handle: phone
  field: { type: text, required: { if: { contact_by: phone } } }
```

The Control Plane draws the `*` beside Phone only while Contact by is Phone. A field its own conditions hide is never
required, whatever its `required` says. A conditionally required `toggle` must be switched on once the condition passes.
`nibble:check` refuses a `required` condition with no key or several, and one naming a field that isn't beside it. Its
warning about saved records with a required toggle switched off covers only `required: true`.

### What a hidden field keeps

A condition decides whether a field is validated; it never removes the value. When a condition hides a field, Nibble
skips that field's rules, so nothing in it is required or checked, and the value already saved with the record stays:

- Saving an entry, term or global set from the Control Plane sends the values of hidden fields along with the rest, and
  stores them as sent. Hiding a field does not clear it, and showing it again brings back what was there.
- The API and agents write whatever values they are given; a hidden field's value is stored and not checked.
- A public form submission is the same: the hidden field's rules are skipped and a posted value is stored, emailed and
  delivered as posted. Only [calculations](forms.md#11-calculations) ignore a hidden field, counting it as 0.
- `always_save: true` on a field keeps its rules running while a condition hides it, so a hidden `required` field is still
  required and its other rules still apply. It makes no difference to what is stored, because values are stored either
  way.

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

---
id: reference-fieldtypes
title: Fieldtypes and field options
description: Every fieldtype Nibble ships with what it stores and each option it takes, then the options every field
  takes.
order: 1
---

# Fieldtypes and field options

A field is written `field: { type: …, …options }` in a blueprint (see [Blueprints and fields](../modelling/blueprints.md)).
This page lists the options every field takes, then each fieldtype with what it stores and the options it adds. A
field with an option its fieldtype doesn't have is refused by `bin/rails nibble:check`.

- [Options every field takes](#options-every-field-takes)
- Text: [`text`](#text), [`textarea`](#textarea), [`code`](#code), [`rich_text`](#rich_text), [`markdown`](#markdown), [`slug`](#slug), [`secret`](#secret)
- Numbers and dates: [`integer`](#integer), [`decimal`](#decimal), [`range`](#range), [`rating`](#rating), [`date`](#date), [`time`](#time), [`calculation`](#calculation)
- Choice: [`select`](#select), [`radio`](#radio), [`button_group`](#button_group), [`checkboxes`](#checkboxes), [`toggle`](#toggle), [`list`](#list), [`color`](#color)
- Relationships and links: [`entries`](#entries), [`terms`](#terms), [`link`](#link)
- Files: [`assets`](#assets), [`files`](#files)
- Repeating: [`grid`](#grid), [`replicator`](#replicator)
- Whole page: [`seo`](#seo)
- Display only: [`note`](#note)

Under each fieldtype, **Public forms** says whether a [public form](../modelling/forms.md) may use it (the others are
refused by `nibble:check`). An option's **Default** is what applies when the field doesn't set it; a dash means
the option has no default and is simply off.

## Options every field takes

| Option | Type | Default | What it does |
|---|---|---|---|
| `type` | text | `text` | the fieldtype's handle, one of those below |
| `display` | text, or a map of locale to text | the handle, humanised | the label |
| `instructions` | text, or a map of locale to text | — | help text for the editor |
| `instructions_position` | `above`, `below` | `above` | where the help text sits: under the label or under the input |
| `width` | `25`, `33`, `50`, `66`, `75` or `100` | `100` | how much of the row the field takes, as a percentage |
| `required` | `true`, `false`, or a [condition](conditions.md#required-and-read_only-conditions) | `false` | a value is needed to save. A `toggle` must be switched on. A condition makes it required only while the condition passes |
| `validate` | a rule, a list of rules, or rules joined with `\|` | — | extra [validation rules](validation.md), such as `[max:200]`. A `required` rule here is the same as `required: true` |
| `messages` | map of rule name to text, or to a map of locale to text | — | the wording of a failed rule; see [Changing a rule's message](validation.md#changing-a-rules-message) |
| `default` | any value, or `computed:<name>` | the fieldtype's own empty value | what a new entry, term, global or row starts with; see [Defaults](#defaults) |
| `visibility` | `visible`, `read_only`, `hidden`, `computed` | `visible`, or `read_only` when `read_only: true` | how the Control Plane treats the field; see [Visibility and read-only](#visibility-and-read-only) |
| `read_only` | `true`, `false`, or a [condition](conditions.md#required-and-read_only-conditions) | `false` | shown but not editable, and kept as it is on every save. A condition makes it read-only only while it passes |
| `always_save` | `true`, `false` | `false` | keeps the field's validation running while a [condition](conditions.md#what-a-hidden-field-keeps) hides it |
| `localizable` | `true`, `false` | `false` | the value differs per locale. `files`, `calculation` and `note` can't be localised |
| `listable` | `true`, `hidden`, `false` | `hidden` | `true` shows the field as a column in the collection's listing, `hidden` offers it in the column picker, `false` never lists it. A `note` is never listed |
| `api` | `true`, `false` | `true` | `false` leaves the field out of the generated TypeScript types and, from `load_defaults` 0.15.0, out of the Content API. A page still receives it. A `note` is always left out |
| `hide_display` | `true`, `false` | `false` | the Control Plane draws the field without its label |
| `actions` | `true`, `false` | `true` | `false` leaves out the field's action menu in the Control Plane |
| `replicator_preview` | `true`, `false` | `true` | whether the field's value appears in the collapsed header of a replicator block it is in |
| `hidden` | `true`, `false` | `false` | public forms only: the visitor never sees the field. Needs a `value` or a `prefill` |
| `prefill` | `{ query: <parameter> }` | — | public forms only, with `hidden: true`: fills the field from that parameter of the page's query string |
| `value` | text, number or `true`/`false` | — | public forms only, with `hidden: true`: the value the field carries. With a `prefill`, it is used only when the query parameter and the post are both empty; without one, it is stored whatever is posted |
| `encrypt` | `true`, `false` | `false` | public forms only: the submission stores the value encrypted. Not on `files` |
| `if`, `if_any`, `unless`, `unless_any`, `show_when`, `show_when_any`, `hide_when`, `hide_when_any` | a [condition](conditions.md) | — | shows or hides the field while the condition passes. A field takes at most one |
| `sortable`, `filterable`, `duplicate` | `true`, `false` | — | accepted and kept in the schema; Nibble doesn't act on them |

`hidden`, `prefill`, `value` and `encrypt` are written the same way in any blueprint but only a public form acts on
them. [Forms](../modelling/forms.md) explains each in use.

### Defaults

A `default` is a literal value, or `computed:<name>` to resolve it when a record is made. Nibble has one built in,
`computed:today`, the current date in the site's time zone as `YYYY-MM-DD`:

```yaml
field: { type: date, default: computed:today }
```

A site registers its own in an initializer, and `nibble:check` refuses a name nobody registered:

```ruby
# config/initializers/defaults.rb
Nibble::Defaults.register("quarter") { "Q#{(Time.zone.today.month - 1) / 3 + 1}" }
```

A default fills a new record, and rows added later in a grid or replicator. Records that already exist keep what they
have; [`set_default`](../modelling/changing-schema.md#42-set_default) fills them. `files`, `calculation` and `note` take
no default.

### Visibility and read-only

| `visibility` | In the Control Plane | On save |
|---|---|---|
| `visible` | drawn and editable | validated and stored |
| `read_only` | drawn, not editable | the stored value is kept whoever saves; see [Blueprints and fields](../modelling/blueprints.md#2-options-every-field-takes) |
| `hidden` | not drawn | validated like a visible field |
| `computed` | drawn, not editable | not validated |

`read_only: true` is the same as `visibility: read_only`; setting both, `visibility` wins. A condition under `read_only`
is evaluated against the values being saved and is separate from `visibility`.

## Text

### `text`

A single line. Stores text, or a number when `input_type` is `number`. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `input_type` | `color`, `date`, `email`, `hidden`, `month`, `number`, `password`, `tel`, `text`, `time`, `url`, `week` | `text` | the input a theme draws. `email`, `url`, `tel` and `number` also check the value |
| `character_limit` | whole number | — | the longest text accepted; adds a `max` rule |
| `autocomplete` | text | — | the HTML `autocomplete` value for the input |
| `placeholder` | text | — | text shown in the empty input |
| `prepend`, `append` | text | — | text drawn before and after the input |

`input_type` checks, on a blueprint and on a public form alike; a blank value always passes:

| `input_type` | Accepts | Rule added | Message key |
|---|---|---|---|
| `email` | an email address | `email` | `email` |
| `url` | an absolute `http://` or `https://` address | `url:web` | `url` |
| `tel` | digits, spaces and `+ ( ) . -`, with at least three digits | `phone` | `phone` |
| `number` | a number, stored as a number | `numeric` | `numeric` |

A field's own `regex:` rule replaces the `tel` check, so a site can ask for the numbers it takes.

`nibble:check` warns when saved entries, terms or global sets hold an email, URL or phone that fails its check, with how many and
the first few ids; they can't be saved again until the value is corrected.

```yaml
field: { type: text, input_type: email, required: true, character_limit: 120 }
```

### `textarea`

Several lines of plain text. Stores text. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `placeholder` | text | — | text shown in the empty input |
| `character_limit` | whole number | — | the longest text accepted; adds a `max` rule |
| `rows` | whole number | — | how many lines tall the input is |

```yaml
field: { type: textarea, character_limit: 280, rows: 4 }
```

### `code`

An editor for HTML, with line numbers and highlighting, for snippets pasted from another tool. Stores text.
**Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `placeholder` | text | — | text shown when empty |
| `rows` | whole number | `8` | how many lines tall the editor is |

```yaml
field: { type: code, rows: 12 }
```

### `rich_text`

The full editor: headings, lists, links, images, tables, code blocks and find-and-replace. Stores structured data, not
HTML; the server renders it to safe HTML, so a theme never receives markup it has to trust. A link can point at a
[global field](../modelling/globals-and-navigation.md#12-linking-to-a-global-from-rich-text) and follows it when it
changes. With `sets`, a page receives a list of text and set blocks instead of one string. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `buttons` | list of button names | `h2 h3 bold italic unorderedlist orderedlist removeformat quote anchor image table` | the toolbar. Also available: `h4`, `underline`, `strikethrough`, `code`, `codeblock` and `horizontalrule`. Naming `table` also offers the table editing buttons |
| `reading_time` | `true`, `false` | `false` | shows the estimated reading time |
| `word_count` | `true`, `false` | `false` | shows the word count |
| `fullscreen` | `true`, `false` | `true` | offers a full-screen mode |
| `image_preset` | text | `content` | the [image size](../running/configuration.md#5-image-presets) used for images in the text |
| `target_blank` | `true`, `false` | `false` | a new link opens in a new window by default |
| `inline` | `true`, `false` | `false` | one line of text with no paragraphs; stored and rendered without a wrapping paragraph |
| `remove_empty_nodes` | `false`, `true`, `trim` | `false` | `true` drops empty paragraphs and headings when saving; `trim` drops only those at the start and end |
| `sets` | map of sets | — | blocks an editor can insert between paragraphs, declared as in a [replicator](#replicator) |
| `collapse` | `true`, `false` | `false` | with `sets`, the editor opens with every block folded |
| `placeholder` | text | — | accepted; the Control Plane doesn't act on it |
| `character_limit` | whole number | — | accepted; the Control Plane doesn't act on it |
| `toolbar_mode` | `fixed`, `floating` | `fixed` | accepted; the Control Plane doesn't act on it |
| `smart_typography` | `true`, `false` | `false` | accepted; the Control Plane doesn't act on it |
| `enable_input_rules`, `enable_paste_rules` | `true`, `false` | `true` | accepted; the Control Plane doesn't act on them |
| `link_noopener`, `link_noreferrer` | `true`, `false` | `false` | accepted; the Control Plane doesn't act on them |
| `link_collections` | list of collection handles | — | accepted; the Control Plane doesn't act on it |
| `always_show_set_button` | `true`, `false` | `false` | accepted; the Control Plane doesn't act on it |
| `previews` | `true`, `false` | `true` | accepted; the Control Plane doesn't act on it |
| `inline_hard_breaks` | `true`, `false` | `false` | accepted, and offered only with `inline: true`; the Control Plane doesn't act on it |

```yaml
field: { type: rich_text, buttons: [h2, h3, bold, italic, anchor], word_count: true }
```

### `markdown`

A textarea with a Preview button, rendered by the server exactly as a theme receives it. Stores the Markdown text.
**Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `placeholder` | text | — | text shown in the empty input |
| `character_limit` | whole number | — | the longest text accepted; adds a `max` rule |
| `rows` | whole number | `12` | how many lines tall the input is |
| `preview` | `true`, `false` | `true` | offers the Preview button |
| `sanitize` | `true`, `false` | `false` | strips raw HTML from the text when it is rendered; turn it on when the text could come from someone you do not trust |
| `image_preset` | text | `content` | the [image size](../running/configuration.md#5-image-presets) used for images in the text |

```yaml
field: { type: markdown, sanitize: true }
```

### `slug`

A URL-safe name. Stores text. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `generate` | `true`, `false` | `true` | fills the slug from `from` while it is empty |
| `from` | field handle | `title` | the field the slug is made from |
| `separator` | text | `-` | what replaces spaces and punctuation |
| `show_regenerate` | `true`, `false` | `false` | shows a button that makes the slug again from `from` |

```yaml
field: { type: slug, from: name, separator: _ }
```

### `secret`

A value stored encrypted and never shown again in full, such as an API key a setting needs. A page and the Content API
never receive it. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `placeholder` | text | — | text shown in the empty input |

```yaml
field: { type: secret, display: API key }
```

## Numbers and dates

### `integer`

A whole number. Stores a number. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `min`, `max` | whole number | — | the smallest and largest value accepted |
| `step` | whole number | — | what the input moves by. A blueprint only hints; a public form also refuses a value that is off the step, counted from `min` (or 0), with the message key `step` |
| `placeholder` | text | — | text shown in the empty input |
| `prepend`, `append` | text | — | text drawn before and after the number |

```yaml
field: { type: integer, min: 1, max: 20, append: guests }
```

### `decimal`

A number with a fixed number of places, such as a price. Stores a number, never text. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `decimals` | `0` to `10` | `2` | how many places to keep. A value is rounded half away from zero when saved, so `2.675` is stored as `2.68` and `-2.675` as `-2.68` |
| `min`, `max` | number | — | the smallest and largest value accepted |
| `step` | number | the smallest step `decimals` allows | what the input moves by; a hint to the input, not a rule |
| `placeholder` | text | — | text shown in the empty input |
| `prepend`, `append` | text | — | text drawn before and after the number |

A submission list, an email and an export show the value with exactly `decimals` places.

```yaml
field: { type: decimal, decimals: 2, min: 0, prepend: $ }
```

### `range`

A slider. Stores a number: whole when `min`, `max` and `step` are all whole, a decimal otherwise. A value outside `min`
and `max` is refused. `default` is where the slider starts. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `min` | number | `0` | the lowest value |
| `max` | number | `100` | the highest value |
| `step` | number | `1` | what the slider moves by |
| `prepend`, `append` | text | — | text drawn around the value shown beside the slider |

```yaml
field: { type: range, min: 0, max: 10, default: 5, append: " / 10" }
```

### `rating`

A row of stars. Stores a whole number from 1 to `max`, or nothing when it has not been rated; the editor clears it by
choosing the same star again. A value outside 1 to `max` is refused. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `max` | `2` to `10` | `5` | how many stars |

```yaml
field: { type: rating, max: 5 }
```

### `date`

A date, or a date and time. Stores `YYYY-MM-DD`, or with `time_enabled` a UTC date-time such as
`2026-07-15T09:00:00Z`. With a `time_zone` a page receives the time in that zone, with its offset
(`2026-07-15T09:00:00+10:00`). **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `time_enabled` | `true`, `false` | `false` | also asks for a time |
| `time_seconds_enabled` | `true`, `false` | `false` | with `time_enabled`, keeps seconds; otherwise they are dropped |
| `time_zone` | an IANA name such as `Europe/London`, or `site` | — | with `time_enabled`, the clock the person types on, read with the offset that zone has on that date. `site` is the zone the site is set to (`config.time_zone` in `config/application.rb`). Without it, a date-time is stored in UTC and shown in the site's zone |
| `earliest_date`, `latest_date` | date | — | the first and last date accepted, both included; midnight in `time_zone` when it has one |
| `inline` | `true`, `false` | `false` | draws the calendar open instead of behind an input |
| `full_width` | `true`, `false` | `false` | accepted; the Control Plane doesn't act on it |

A time the clocks skip when they go forward, such as 02:30 on the night summer time starts, is refused with the
message key `local_time`. A time they repeat when they go back is the first of the two. Adding a zone to a field that
already has values keeps them: each is the same moment, shown in the new zone. `nibble:check` refuses a zone it
doesn't know.

```yaml
field: { type: date, time_enabled: true, time_zone: Australia/Sydney, earliest_date: "2026-01-01" }
```

### `time`

A time of day on the 24-hour clock. Stores text such as `"14:30"`, or `"14:30:05"` with `seconds`. Anything but a
24-hour time is refused, so `9:30`, `24:00` and `noon` never reach a page. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `seconds` | `true`, `false` | `false` | stores seconds too; when off, seconds a browser sends are dropped |
| `earliest`, `latest` | a time in quotes | — | the earliest and latest time accepted, both included, such as `"09:00"` and `"17:30"` |
| `placeholder` | text | — | text shown in the empty input |

Write times in quotes: YAML reads an unquoted `09:00` as a number, and `nibble:check` refuses it.

```yaml
field: { type: time, earliest: "09:00", latest: "17:30" }
```

### `calculation`

A number a public form works out from its other fields; see [Calculations](../modelling/forms.md#11-calculations). It
stores the server's result and ignores any value posted. It can't be `required`, `hidden` or given a `default`.
**Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `formula` | text | — | the sum, such as `{quantity} * {unit_price}` |
| `decimals` | `0` to `15` | — | how many places to show; unset shows up to 10, without trailing zeros |
| `prepend`, `append` | text | — | text drawn before and after the result |

```yaml
field: { type: calculation, formula: "{quantity} * {unit_price}", decimals: 2, prepend: $ }
```

## Choice

### `select`

A dropdown over a fixed list written in the blueprint. Stores the chosen value, or a list of values with `multiple`.
For a list editors manage themselves, use a taxonomy with a [`terms`](#terms) field instead. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `options` | a map, a list of values, or a list of `{ value, label }` | — | the choices; see [Writing options](#writing-options) |
| `taggable` | `true`, `false` | `false` | the person may type a value that isn't in `options`; the `in` check is dropped |
| `placeholder` | text | — | text shown when nothing is chosen |
| `clearable` | `true`, `false` | `false` | offers a way to clear the choice |
| `searchable` | `true`, `false` | `true` | the dropdown has a search box |
| `multiple` | `true`, `false` | `false` | stores a list instead of one value |
| `max_items` | whole number | — | with `multiple`, the most values accepted |
| `cast_booleans` | `true`, `false` | `false` | the options `true` and `false` are stored as booleans rather than text |

```yaml
field: { type: select, options: { s: Small, m: Medium, l: Large }, default: m }
```

### `radio`

One choice from a short list, drawn as radio buttons. Stores the chosen value. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `options` | a map, a list of values, or a list of `{ value, label }` | — | the choices; see [Writing options](#writing-options) |
| `inline` | `true`, `false` | `false` | lays the buttons out in a row |
| `cast_booleans` | `true`, `false` | `false` | the options `true` and `false` are stored as booleans rather than text |

```yaml
field: { type: radio, options: { phone: Phone, email: Email }, inline: true }
```

### `button_group`

A `radio` drawn as a row of joined buttons, for a few short choices such as sizes. It stores the same value and reaches
a page the same way, so a field can switch between the two without touching its content. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `options` | a map, a list of values, or a list of `{ value, label }` | — | the choices; see [Writing options](#writing-options) |
| `cast_booleans` | `true`, `false` | `false` | the options `true` and `false` are stored as booleans rather than text |

```yaml
field: { type: button_group, options: [S, M, L] }
```

### `checkboxes`

Several choices from a short list. Stores a list of the chosen values. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `options` | a map, a list of values, or a list of `{ value, label }` | — | the choices; see [Writing options](#writing-options) |
| `inline` | `true`, `false` | `false` | lays the boxes out in a row |

```yaml
field: { type: checkboxes, options: { news: News, offers: Offers } }
```

### Writing options

`options` takes any of three shapes, and a page receives each choice as `{ value, label }`:

```yaml
options: { s: Small, m: Medium }                       # value: label
options: [Small, Medium]                               # the value is the label
options:
  - { value: s, label: Small }                         # `key` works in place of `value`
  - { value: m, label: { en: Medium, fr: Moyen } }     # a label per locale
```

The value saved must be one of the options, unless the field is a `taggable` select.

### `toggle`

A switch. Stores `true` or `false`; a new record starts it off. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `inline_label` | text, or a map of locale to text | — | the text beside the switch. It may hold Markdown links, such as `I agree to the [privacy policy](/privacy)`: a link may go to a web, email or phone address or a page on the site, and anything else, such as `javascript:`, is shown as plain text. Nothing else becomes markup |
| `inline_label_when_true` | text | — | replaces `inline_label` while the switch is on |

A `required` toggle has to be switched on. See the [consent checkbox recipe](../modelling/forms.md#13-a-consent-checkbox).

```yaml
field: { type: toggle, inline_label: "I agree to the [terms](/terms)", required: true }
```

### `list`

A list of short text values the editor adds one at a time. Stores a list; items that look like numbers are stored as
numbers and blank items are dropped. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `add_row` | text | — | the label of the button that adds an item |

```yaml
field: { type: list, add_row: Add feature }
```

### `color`

A colour. Stores lowercase `#rrggbb`; a value typed in capitals is stored in lowercase, and anything else (`#fff`,
`red`, a colour with transparency) is refused. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `swatches` | list of `#rrggbb` colours | — | colours offered as buttons |
| `allow_any` | `true`, `false` | `true` | also offers a colour picker and a box for the hex value; `false` accepts only a swatch, and `default` must be one |

On a public form, a browser's colour input always holds a colour, so an optional `color` field drawn as one and posted
without JavaScript arrives as `#000000` when the visitor didn't pick. With JavaScript, `useNibbleForm` posts nothing
until they do. Swatch radios (`allow_any: false`) post nothing either way.

```yaml
field: { type: color, swatches: ["#1a2b3c", "#ffffff"], allow_any: false, default: "#ffffff" }
```

## Relationships and links

### `entries`

Opens a picker over entries and stores a reference, not a copy, so renaming or moving the target keeps the reference
working. Stores a list of entry ids, or one id with `max_items: 1`; a page receives each as an entry summary.
**Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `collections` | list of collection handles | all | the collections the picker offers |
| `max_items` | whole number | — | the most entries accepted; `1` makes a single choice |
| `mode` | `default`, `select`, `typeahead` | `default` | sent to the Control Plane with the field; the picker doesn't change with it |
| `create` | `true`, `false` | `true` | sent to the Control Plane with the field; the picker doesn't change with it |

```yaml
field: { type: entries, collections: [posts], max_items: 3 }
```

### `terms`

The same for taxonomy terms. Stores a list of term ids, or one with `max_items: 1`. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `taxonomies` | list of taxonomy handles | all | the taxonomies the picker offers |
| `max_items` | whole number | — | the most terms accepted; `1` makes a single choice |
| `mode` | `default`, `select`, `typeahead` | `default` | sent to the Control Plane with the field; the picker doesn't change with it |
| `create` | `true`, `false` | `true` | sent to the Control Plane with the field; the picker doesn't change with it |

```yaml
field: { type: terms, taxonomies: [topics], max_items: 1 }
```

### `link`

A web, email or phone address, or a link to an entry or term that follows it if it moves. Stores text: an address, or
a reference such as `entry::12`. A page receives `{ type, url, title }`, with `id` for a reference. Only web, email,
phone and on-site links are accepted. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `default_option` | `url`, `entry` or `term` | — | which kind of link the field opens on while empty |
| `collections` | list of collection handles | all | the collections an entry link may choose from |
| `taxonomies` | list of taxonomy handles | all | the taxonomies a term link may choose from |

```yaml
field: { type: link, collections: [pages] }
```

## Files

### `assets`

Opens the media library. Stores `{ asset, alt }` references, a list or one with `max_files: 1`; a page receives each
asset with its URL and the alt text. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `max_files` | whole number | — | the most files accepted; `1` makes a single image |
| `min_files` | whole number | — | the fewest files accepted |
| `alt` | `optional`, `required`, `none` | `optional` | whether each file's alt text is asked for, required, or not offered |
| `preset` | text | — | the [image size](../running/configuration.md#5-image-presets) a theme receives |
| `folder` | text | — | the media folder the picker opens in |
| `restrict` | `true`, `false` | `false` | with `folder`, offers only that folder's assets |
| `allow_uploads` | `true`, `false` | `true` | lets the person upload from the field |
| `mode` | `grid`, `list` | `grid` | how the chosen files are laid out |
| `allowed_types` | list of file types | — | restricts the files the picker offers |

```yaml
field: { type: assets, max_files: 1, alt: required, preset: hero, width: 50 }
```

### `files`

Uploads from a visitor on a public form, such as a brief or a logo, kept with the submission. Stores a list of
`{ id, filename, size, content_type }`. It can't be `encrypt`ed or `hidden`. **Public forms:** yes, and meant for them.

| Option | Type | Default | What it does |
|---|---|---|---|
| `max_files` | whole number | `1` | the most files accepted |
| `max_file_size` | whole number, in megabytes | `10` | the largest file accepted |
| `extensions` | list of extensions | `pdf doc docx xls xlsx csv txt jpg jpeg png gif webp heic` | the extensions accepted |

```yaml
field: { type: files, max_files: 3, max_file_size: 5, extensions: [pdf, png] }
```

## Repeating

### `grid`

Rows of the same fields, such as opening hours or a price list. Stores a list of rows, each with an `id`.
**Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `fields` | list of fields | — | the fields of a row, written like a blueprint's: `handle` and `field` |
| `mode` | `table`, `stacked` | `table` | one row of cells, or each row's fields wrapped |
| `add_row` | text | — | the label of the button that adds a row |
| `reorderable` | `true`, `false` | `true` | rows can be dragged into order |
| `min_rows`, `max_rows` | whole number | — | the fewest and most rows accepted |
| `fullscreen` | `true`, `false` | `true` | accepted; the Control Plane doesn't act on it |

```yaml
field:
  type: grid
  add_row: Add plan
  fields:
    - handle: name
      field: { type: text, required: true }
    - handle: price
      field: { type: decimal }
```

### `replicator`

A list of blocks, each one of several shapes. Stores a list of blocks, each with an `id` and a `type`. The sets and
what each can carry are in [Pages built from blocks](../modelling/blueprints.md#4-pages-built-from-blocks).
**Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `sets` | map of sets, or of groups of sets | — | the kinds of block. A set takes `display`, `fields`, `instructions`, `icon`, `badge` and `max` |
| `max_sets` | whole number | — | the most blocks of every set together |
| `button_label` | text | — | the label of the Add button |
| `button_position` | `below`, `header` | `below` | where the Add button sits; `header` puts it in the header of the section the field is in |
| `insert_below` | `true`, `false` | `true` | `false` leaves out the button on each block that adds another beneath it |
| `tab_count` | `true`, `false` | `false` | shows how many blocks are switched on beside the tab's name |
| `collapse` | `false`, `true`, `accordion` | `false` | `true` opens the editor with every block folded; `accordion` also keeps one open at a time |
| `previews` | `true`, `false` | `true` | accepted; the Control Plane doesn't act on it |
| `fullscreen` | `true`, `false` | `true` | accepted; the Control Plane doesn't act on it |

```yaml
field:
  type: replicator
  button_label: Add block
  sets:
    quote:
      display: Quote
      fields:
        - handle: text
          field: { type: textarea }
```

## Whole page

### `seo`

A page's search and sharing settings. Stores an object with `title`, `exact_title`, `description`, `canonical`,
`og_image`, `noindex`, `nositemap`, `schema_type` and `json_ld_overrides`. `canonical` must be an `https://` address or
a path. Most blueprints import it as the fieldset `nibble::seo` rather than declaring it. **Public forms:** no.

| Option | Type | Default | What it does |
|---|---|---|---|
| `title_limit` | whole number | `60` | the length the title is judged against in the Control Plane |
| `description_limit` | whole number | `160` | the length the description is judged against in the Control Plane |
| `schema_types` | list of schema.org types | `WebPage Article BlogPosting FAQPage Organization LocalBusiness Product Event` | the choices for `schema_type`, which must be one of them |

```yaml
field: { type: seo, schema_types: [WebPage, Article] }
```

## Display only

### `note`

Text for the editor or visitor to read, which holds no value. `text` is Markdown, per locale if the site has several:
paragraphs, emphasis, lists and links to web, email, phone or site addresses are kept, and everything else, including raw
HTML, headings and images, is dropped. The Control Plane draws it as a muted block across the form, and a public form
passes it to the theme as `text_html`. A note is never stored, exported, emailed, searched, listed in the Content API, or
offered to connected apps to write. It can't be `required`, `hidden`, `encrypt`ed or have a `default`; `nibble:check`
refuses those. **Public forms:** yes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `text` | Markdown, or a map of locale to Markdown | — | what the note says |

```yaml
field:
  type: note
  text: |
    Prices include **GST**. See the [price list](/prices) for what is covered.
```

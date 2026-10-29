---
id: reference-validation
title: Validation rules
description: Every rule a field's validate option accepts, with its arguments, its message key and how to reword it.
order: 2
---

# Validation rules

A field's `validate` lists extra rules a value must pass before it is saved, in a blueprint and on a
[public form](../modelling/forms.md) alike. This page lists every rule, how to write one, and how to change what it
says.

## Writing rules

A rule is its name, then `:` and its arguments separated by commas. `validate` takes a list, or one string with the
rules joined by `|`; the two are the same:

```yaml
field:
  type: text
  validate: [min:2, max:80, "starts_with:Mr,Ms"]
```

```yaml
field: { type: text, validate: "min:2|max:80" }
```

- **Blank values skip every rule** except the ones that decide whether a value is needed: `required`, `required_if`,
  `required_unless`, `required_with`, `required_without` and `accepted`. A blank is `null` or `""`.
- When one of those "needed" rules fails, the field's remaining rules aren't run; the others report together.
- [`nullable` and `sometimes`](#optional-values) say what happens to a value that is blank or left out.
- A fieldtype adds rules of its own, such as `integer` on an `integer` field; see [Rules a fieldtype
  adds](#rules-a-fieldtype-adds). Yours run beside them.
- A rule that doesn't exist fails loudly rather than being skipped, and `nibble:check` refuses it.

### Naming other fields

Rules that look at another field (`required_if`, `required_with`, `same`, `after` and the rest) name it by its handle.
A field inside a grid row or a replicator block names a sibling with the `{this}.` prefix, which stands for the path
to the current row:

```yaml
- handle: button_label
  field: { type: text }
- handle: button_link
  field: { type: link, validate: ["required_with:{this}.button_label"] }
```

Outside a grid or replicator `{this}.` is empty, so the same rule works at the top level. A nested value is named by
its dotted path, such as `address.postcode`.

`{id}`, `{locale}` and `{type}` in a rule are replaced with the record's id, its locale and its type (`form_submission`
on a public form). `{type}` is how a rule can refer to the kind of record it is on.

### Message keys

When a rule fails, Nibble says something like "The Phone field format is invalid." The **Message key** column below
is the name under which that wording is kept. `min`, `max`, `between` and `size` have a wording for numbers, text and
lists, and pick by the value: a list or a group of values is measured by its count, a value checked by `numeric` or
`integer` by its number, and anything else by its length in characters.

## Rules

### Needed

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `required` | — | the value isn't blank; a `toggle` must be on. Same as `required: true` | `required` |
| `required_if` | `field,value,…` | the value isn't blank whenever `field` holds any of the values; `true`, `false` and `null` stand for those | `required_if` |
| `required_unless` | `field,value,…` | the value isn't blank unless `field` holds one of the values | `required_unless` |
| `required_with` | `field,…` | the value isn't blank whenever any named field isn't | `required_with` |
| `required_without` | `field,…` | the value isn't blank whenever any named field is | `required_without` |
| `accepted` | — | the value is `true`, `1`, `"1"`, `"yes"`, `"on"` or `"true"` | `accepted` |

```yaml
validate: ["required_if:contact_by,phone"]
```

### Optional values

| Rule | Arguments | Effect | Message key |
|---|---|---|---|
| `nullable` | — | none; it says in the schema that a blank value is fine | none |
| `sometimes` | — | skips all of the field's rules when the key wasn't sent at all | none |

### Type

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `string` | — | the value is text | `string` |
| `numeric` | — | a number, or text that reads as one | `numeric` |
| `integer` | — | a whole number, or text of digits with an optional minus | `integer` |
| `boolean` | — | `true`, `false`, `0`, `1`, `"0"` or `"1"` | `boolean` |
| `array` | — | a list or a group of values | `array` |

### Size

`min`, `max`, `between` and `size` measure a number by its value, text by its length in characters and a list by how
many items it has (see [Message keys](#message-keys)).

| Rule | Arguments | Passes when | Message keys |
|---|---|---|---|
| `min` | `n` | the size is at least `n` | `min` |
| `max` | `n` | the size is at most `n` | `max` |
| `between` | `min,max` | the size is from `min` to `max`, both included | `between` |
| `size` | `n` | the size is exactly `n` | `size` |

The wording for each has three forms (`min.numeric`, `min.string`, `min.array`, and likewise for the others); a
field's `messages.min` sets all three.

```yaml
validate: [min:2, max:80]
```

### Format

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `email` | — | the value is an email address | `email` |
| `url` | `web` (optional) | the value is an absolute URL with a scheme and a host (or `mailto:`). With `web`, only an `http://` or `https://` address | `url` |
| `phone` | — | digits, spaces and `+ ( ) . -`, with at least three digits | `phone` |
| `safe_link` | — | a web, email or phone link, or a link to content on this site | `safe_link` |
| `alpha` | — | letters only | `alpha` |
| `alpha_num` | — | letters and numbers only | `alpha_num` |
| `alpha_dash` | — | letters, numbers, dashes and underscores only | `alpha_dash` |
| `regex` | `/pattern/flags` | the value matches the pattern | `regex` |
| `not_regex` | `/pattern/flags` | the value doesn't match the pattern | `not_regex` |
| `lowercase` | — | the value is lowercase | `lowercase` |
| `uppercase` | — | the value is uppercase | `uppercase` |
| `starts_with` | `text,…` | the value starts with one of the texts | `starts_with` |
| `ends_with` | `text,…` | the value ends with one of the texts | `ends_with` |

A `regex` is written between delimiters, usually `/`, then the flags `i`, `m`, `x` or `s`. Commas inside it are part of
the pattern, because the whole text after `regex:` is the pattern. `^` and `$` match the start and end of the whole
value, and a `\` must be doubled inside double quotes in YAML:

```yaml
validate: ["regex:/^04\\d{8}$/i"]
```

### Choices

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `in` | `value,…` | the value, or every item of a list, is one of those listed | `in` |
| `not_in` | `value,…` | no value is one of those listed | `not_in` |
| `same` | `field` | the value equals the other field's | `same` |
| `different` | `field` | the value differs from the other field's | `different` |

### Dates and times

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `date` | — | the value reads as a date | `date` |
| `after` | `field` or a date or `now`, `today`, `tomorrow`, `yesterday` | the date is later than that | `after` |
| `after_or_equal` | same | the date is that or later | `after_or_equal` |
| `before` | same | the date is earlier than that | `before` |
| `before_or_equal` | same | the date is that or earlier | `before_or_equal` |
| `time` | — | a 24-hour time such as `14:30` | `time` |
| `earliest_time` | `time` | a time of day no earlier than that | `earliest_time` |
| `latest_time` | `time` | a time of day no later than that | `latest_time` |
| `local_time` | zone name | the time exists on that zone's clocks, not in the hour they skip when they go forward | `local_time` |

An argument that names a field of the record is compared with that field's date; otherwise it is read as a date. A
value that isn't a date fails with the `date` message.

```yaml
validate: ["after:today", "before_or_equal:ends_on"]
```

### Colour

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `color` | — | the value is written `#rrggbb` | `color` |

### Files and records

| Rule | Arguments | Passes when | Message key |
|---|---|---|---|
| `mimes` | `extension,…` | every uploaded file has one of those extensions | `mimes` |
| `max_file_size` | `megabytes` | every uploaded file is within that size | `max_file_size` |
| `max_of_set` | `set,n` | a replicator or rich text field holds at most `n` blocks of the set | `max_of_set` |
| `records_exist` | `type,key=a;b` | every item named is a record of that kind that this field may choose | `records_exist` |
| `global_links` | — | every link to a global field in rich text names a web-address field of a global set | `global_links` |

## Rules a fieldtype adds

A fieldtype adds the rules its options imply, so `max_files: 3` needs no `validate`. They report under their own
message keys, and a field's `messages` can reword them.

| Fieldtype | Rules it adds |
|---|---|
| `text` | `email`, `url:web`, `numeric` or `phone` for the matching `input_type`; `max` for `character_limit` |
| `textarea`, `markdown` | `max` for `character_limit` |
| `integer` | `integer`, `min`, `max` |
| `decimal` | `numeric`, `min`, `max` |
| `range` | `numeric`, `min`, `max` |
| `rating` | `integer`, `min:1`, `max` |
| `select`, `radio`, `button_group`, `checkboxes` | `in` the options (not on a `taggable` select), `max` for a multiple select's `max_items` |
| `date` | `date`, `local_time` for a `time_zone`, `after_or_equal` for `earliest_date`, `before_or_equal` for `latest_date` |
| `time` | `time`, `earliest_time`, `latest_time` |
| `color` | `color`, and `in` the swatches when `allow_any` is `false` |
| `link` | `string`, `safe_link` |
| `entries`, `terms` | `array`, `max` for `max_items`, `records_exist` |
| `assets` | `array`, `min` and `max` for `min_files` and `max_files`, `records_exist`; a missing alt text when `alt: required` |
| `files` | `array`, `max` for `max_files`, `mimes`, `max_file_size` |
| `grid` | `array`, `min` and `max` for `min_rows` and `max_rows` |
| `replicator` | `array`, `max` for `max_sets`, `max_of_set` for a set's `max` |
| `rich_text` | `global_links` |
| `seo` | its own checks of the title, description, canonical URL, share image, schema type and overrides |

## Changing a rule's message

A failed rule says, for example, "The Phone field format is invalid." A field's `messages` rewords it, keyed by the
message key of a rule the field has. Each value is text, or a map of locale code to text:

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

- The wording is used in the locale of the record or submission, then the site's default locale, then Nibble's own.
- It takes the placeholders of the default wording: `%{attribute}` (the field's label) in every message, and the
  rule's own, such as `%{min}`, `%{max}`, `%{size}`, `%{other}`, `%{value}`, `%{values}`, `%{date}`, `%{time}`,
  `%{zone}`, `%{set}` and `%{refs}`.
- `messages.min` covers the number, text and list variants of `min` alike; the same for `max`, `between` and `size`.
- An `integer` field with a `step` on a public form also has the key `step`, with `%{attribute}`, `%{step}` and `%{min}`.
- `nibble:check` refuses a message for a rule the field doesn't have, a value that isn't text, and a locale the site
  doesn't have.

To translate Nibble's own wording for every field at once, add the key under `nibble.validation` to a locale file
of the site, for example `config/locales/fr.yml`. The default wordings are the keys in the table above, with the size
rules split by variant:

```yaml
fr:
  nibble:
    validation:
      required: "Le champ %{attribute} est obligatoire."
      min:
        string: "Le champ %{attribute} doit comporter au moins %{min} caractères."
```

A field's own `messages` still win over these.

## Your own rules

A site registers a rule in an initializer. The block receives the value and returns `nil` when it passes, or the message
to show when it doesn't; `%{attribute}` in the message becomes the field's label. A rule registered `implicit: true`
also runs when the value is blank, as `required` does.

```ruby
# config/initializers/validation.rb
Nibble::Validation.register("not_example_domain") do |value, params:, root_values:, attribute:|
  "%{attribute} can't use example.com" if value.to_s.end_with?("@example.com")
end
```

```yaml
field: { type: text, input_type: email, validate: [not_example_domain] }
```

`params` holds the rule's arguments as a list of text, and `root_values` the values of the whole record being checked.

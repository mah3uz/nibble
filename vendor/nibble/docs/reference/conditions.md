---
id: reference-conditions
title: Conditions
description: The syntax behind if, unless, required and read_only conditions, the operators, paths into other fields,
  custom conditions, and what a hidden field keeps.
order: 3
---

# Conditions

A condition says when something about a field applies, based on the values of other fields. It is used to show or hide a
field, to make it required, and to make it read-only. The same syntax is used in a blueprint and on a
[public form](../modelling/forms.md), and a form's email `notify` entries take it too. The Control Plane and the
server evaluate it the same way, so what an editor sees is what is checked on save.

## The keys

| Key | The field is shown, required or read-only while |
|---|---|
| `if`, `show_when` | every rule passes |
| `if_any`, `show_when_any` | at least one rule passes |
| `unless`, `hide_when` | not every rule passes: it is hidden when they all pass |
| `unless_any`, `hide_when_any` | none of the rules pass: it is hidden when any passes |

`if` and `show_when` mean the same, as do `unless` and `hide_when`. A field uses one key; if it sets several, the first of
`if`, `if_any`, `show_when`, `show_when_any`, `unless`, `unless_any`, `hide_when` and `hide_when_any` counts.

```yaml
- handle: hero_kind
  field: { type: radio, options: { image: Image, video: Video }, default: image }
- handle: hero_image
  field: { type: assets, max_files: 1, if: { hero_kind: image } }
- handle: hero_video_url
  field: { type: text, input_type: url, unless: { hero_kind: image } }
```

## Writing the rules

A key holds a map of field handle to what it must be. Several handles are several rules, combined as the key says
(`if` needs all of them, `if_any` one):

```yaml
if: { kind: business, size: ">= 10" }
if_any: { kind: business, country: AU }
```

The right-hand side is written `<operator> <value>`; a bare value is the same as `equals <value>`. Give a list to put
several rules on one field:

```yaml
if:
  topic: [not billing, not other]
```

Quote a value that starts with `>` or `<`, or YAML reads it as something else. Text is trimmed before it is compared.

### Operators

| Operator | Aliases | Passes when |
|---|---|---|
| `equals` | `is`, `==` | the field is equal to the value. `true`, `false` and `null` stand for those values; `empty` stands for a blank one (`null`, `""`, `[]`, `{}`); two numbers compare as numbers, so `5` equals `"5"` |
| `not` | `isnt`, `!=` | the field is not equal to the value, on the same terms |
| `===` | | equal with no type conversion: `5` is not `"5"` |
| `!==` | | not equal with no type conversion |
| `>`, `>=`, `<`, `<=` | | both sides are numbers and the comparison holds |
| `contains` | `includes` | a list includes the value, or a text contains it |
| `contains_any` | `includes_any` | a list includes one of the comma-separated items in the value, or a text contains one |
| `custom` | | a condition written in Ruby; see [Custom conditions](#custom-conditions) |

```yaml
if:
  kind: is business
  employees: ">= 10"
  extras: contains delivery
  notes: not empty
  region: contains_any nsw, vic
```

Comparing a list or a group of values with `equals`, `not`, `===`, `!==` or a number operator never passes; use
`contains` for a list. A value that isn't a number fails a number operator.

### Fields in other places

A handle names a field beside the one being decided. Inside a grid row or a replicator block that means a field of the
same row. Two prefixes reach further:

| Prefix | Names |
|---|---|
| `$root.` (or `root.`) | a field of the whole record, from anywhere in it |
| `$parent.` | a field one level up from the current row: the record's own fields from a top-level row or block, or the enclosing row from a row nested in another. Repeat it, `$parent.$parent.`, to go further |

A dotted path reaches into a nested value, such as `$root.address.country`.

```yaml
- handle: blocks
  field:
    type: replicator
    sets:
      callout:
        fields:
          - handle: link
            field: { type: link, if: { "$root.show_links": true } }
```

## Where conditions apply

### Showing and hiding a field

`if`, `unless` and the other keys on a field show or hide it. While a condition hides a field:

- the Control Plane doesn't draw it;
- its rules are skipped when a record or submission is saved, so nothing in it is required or checked;
- a public form sends the theme the condition as `conditions`, which `useNibbleForm` evaluates; see
  [Forms](../modelling/forms.md#1-declaring-a-form).

### `required` and `read_only` conditions

`required` and `read_only` each take a condition in place of `true`: a map with exactly one of the keys above. The
condition is checked against the values being saved.

```yaml
- handle: contact_by
  field: { type: radio, options: { phone: Phone, email: Email }, default: email }
- handle: phone
  field: { type: text, required: { if: { contact_by: phone } } }
- handle: locked
  field: { type: toggle }
- handle: reference
  field: { type: text, read_only: { if: { locked: true } } }
```

- `required: { … }` makes the field required while the condition passes and optional while it fails. The Control Plane
  draws the `*` only while it passes. A field its own conditions hide is never required, whatever its `required` says.
  A conditionally required `toggle` must be switched on once the condition passes.
- `read_only: { … }` makes the field read-only while the condition passes, with the same effect as `read_only: true`:
  the stored value is kept as it is on every save.
- `nibble:check` refuses a `required` or `read_only` condition with no key or several, and one naming a field that
  isn't beside it. Its warning about saved records with a required toggle switched off covers only `required: true`.

On a public form, the definition carries a conditional `required` as an object in the shape of `conditions`, where
`show: true` means required while the rules pass; see [Forms](../modelling/forms.md#1-declaring-a-form).

## What a hidden field keeps

A condition decides whether a field is validated; it never removes the value. When a condition hides a field, Nibble
skips that field's rules, so nothing in it is required or checked, and the value already saved with the record stays:

- Saving an entry, term or global set from the Control Plane sends the values of hidden fields along with the rest, and
  stores them as sent. Hiding a field does not clear it, and showing it again brings back what was there.
- The API and agents write whatever values they are given; a hidden field's value is stored and not checked.
- A public form submission is the same: the hidden field's rules are skipped and a posted value is stored, emailed and
  delivered as posted. Only [calculations](../modelling/forms.md#11-calculations) ignore a hidden field, counting it
  as 0.
- `always_save: true` on a field keeps its rules running while a condition hides it, so a hidden `required` field is
  still required and its other rules still apply. It makes no difference to what is stored, because values are stored
  either way.

## Custom conditions

When the operators aren't enough, a site writes the test in Ruby, registers it in an initializer, and names it with
`custom`. The block returns true or false:

```ruby
# config/initializers/conditions.rb
Nibble::Conditions.register("longer_than") do |params:, target:, **|
  target.to_s.length > params.first.to_i
end
```

```yaml
- handle: summary
  field: { type: textarea, if: { title: "custom longer_than:20" } }
```

The text after the name and a colon is the parameters, split on commas. The block receives `params` (a list of text),
`target` (the value of the field it is written against, or `nil` when there is none), `target_handle`, `values` (the
current row), `root_values` (the whole record) and `path` (where the field sits, such as `blocks.0.link`).

A condition can also stand alone, with no field. Write the key's value as the text, and `target` is `nil`:

```yaml
if: "custom is_weekend"
```

A `custom` condition naming something nobody registered raises an error. A theme can't run Ruby, so the server decides
what a `custom` condition does on a public form.

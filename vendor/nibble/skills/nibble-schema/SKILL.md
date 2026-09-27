---
name: nibble-schema
description: Model or change a Nibble site's content — collections, blueprints, fields, taxonomies, globals, navigation and forms — safely, without stranding stored content. Use when asked to add a kind of content, a field, or to rename or remove one.
---

# A Nibble site's schema

Content's shape is YAML. It is read in three layers — Nibble's `vendor/nibble/core_schema/`, then the theme's
`schema/`, then the site's `site/schema/` — and the last to define a handle wins. Content itself is rows whose `data`
is validated against a blueprint built from the schema.

## Where to write

- **Always in `site/schema/`.** Never edit `vendor/nibble/core_schema/`; to change one of Nibble's items, define the
  same handle in `site/schema/`.
- `schema_show` lists every item with the layer it came from; `schema_show` with a key shows one.
- Stubs: `bin/rails nibble:generate:collection <handle>` (also `taxonomy`, `blueprint <collection>/<handle>`,
  `fieldset`, `global`, `navigation`, `form`), or the `generate` tool.

| Item | File |
|---|---|
| collection | `site/schema/collections/<handle>.yml` — route, blueprints, template, dated, structure, feed, `api`, `search` |
| blueprint | `site/schema/blueprints/collections/<collection>/<handle>.yml` — tabs, sections, fields |
| taxonomy | `site/schema/taxonomies/<handle>.yml` |
| global set, navigation, form | `site/schema/globals/`, `navigation/`, `forms/` |
| fieldset (fields written once) | `site/schema/fieldsets/<handle>.yml` |

Fieldtypes: `text`, `textarea`, `markdown`, `rich_text`, `slug`, `integer`, `toggle`, `date`, `link`, `select`,
`radio`, `checkboxes`, `list`, `entries`, `terms`, `assets`, `files`, `grid`, `replicator`, `seo`, `secret`.

## The rule of thumb

**Adding a field is free. Renaming needs a migration. Removing needs a decision.**

| Change | Do |
|---|---|
| add a field, blueprint or collection | just add it |
| rename a field or collection | a content migration (`rename_field`, `rename_collection`) in `site/schema/migrations/` |
| change a field's type | check stored values fit first; migrate if not |
| remove a field, set or collection | migrate the values away, or decide to lose them — never silently |

`nibble:check` refuses a schema that strands stored content, and runs before every deploy. `--allow-data-loss` is
for when a person has decided the data should go; don't reach for it yourself.

## After every change

1. `check` — schema errors, stranded content and theme problems, each with where it is.
2. `bin/rails nibble:schema:types` (a running dev server does this) so the theme's types match.
3. `render` a page that uses the change, and `run_tests`.

Guides: `modelling/collections.md`, `modelling/blueprints.md`, `modelling/changing-schema.md` — `read_doc` or
`search_docs`.

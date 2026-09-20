---
title: Schema
description: Collections, taxonomies, globals, navigation and forms, written as YAML.
order: 1
---

# Schema

Content is defined as code. A collection is a YAML file; the entries in it are rows whose fields are validated
against a blueprint.

Schema is read in **three layers** — Nibble's, then the active theme's, then the site's `schema/` — and the last
to define a handle wins. An override replaces the whole file; it does not merge into it.

```
schema/
  collections/guides.yml
  taxonomies/regions.yml
  blueprints/collections/guides/guide.yml
  fieldsets/seo.yml
  globals/contact.yml
  navigation/main.yml
  forms/enquiry.yml
```

Generate them rather than copying ours:

```sh
bin/rails nibble:generate:collection guides
bin/rails nibble:generate:taxonomy regions
bin/rails nibble:generate:blueprint guides/gallery
bin/rails nibble:generate:fieldset seo
bin/rails nibble:generate:global contact
bin/rails nibble:generate:navigation main
bin/rails nibble:generate:form enquiry
```

Each writes a valid stub into `schema/` and refreshes the theme's generated types. Run `bin/rails nibble:check`
afterwards — it reads every layer and reports anything that will not load, including data the schema no longer
covers.

## A collection

```yaml
title: Guides
route: /guides/{slug}
blueprints: [guide]
sort: published_at:desc
dated: true
template: guides/show
```

`route` decides the URL and `template` the [view](views.md) that renders it. An entry may override the template
for itself, and a blueprint may override it for everything using it.

## Taxonomies, globals, navigation and forms

- **Taxonomies** are terms entries relate to — topics, regions, authors — each with a route of its own.
- **Globals** are a single set of fields for the whole site: contact details, integration keys, anything that is
  not a page.
- **Navigation** is a tree of links to entries or URLs, editable in the control panel.
- **Forms** define fields, validation and what happens on submission. Submissions are stored, and can be emailed.

## Changing a schema that already has content

`bin/rails nibble:check` refuses a change that would orphan stored data, and content migrations under
`schema/migrations/*.yml` move data from the old shape to the new one. They are idempotent, so running one twice
is safe.

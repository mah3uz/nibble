---
title: Building a theme
description: Schema, views and everything that decides how a site looks.
order: 3
---

# Building a theme

A theme is a directory under `themes/`. It holds the schema a site's content is shaped by, the Vue views that
render it, and the styles that dress it.

Start with your own: `bin/rails nibble:generate:theme <name>` copies the starter and names it as the site's, so
you never edit `themes/crumbs`, which an upgrade replaces.

| Page | What it covers |
|---|---|
| [Schema](schema.md) | collections, taxonomies, globals, navigation and forms as YAML |
| [Blueprints and fields](blueprints.md) | what an editor sees, and the fieldtypes available |
| [Views](views.md) | which view renders what, layouts, and sets |
| [Queries](queries.md) | the `.yml` sidecar beside a view, and what it gives the page |
| [Theme helpers](helpers.md) | `@nibble` components for rich text, images and pagination |
| [The Content API](content-api.md) | reading the same content from somewhere else |

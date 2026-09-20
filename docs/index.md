---
title: Nibble
description: A schema-driven CMS you run as your own application.
order: 1
---

# Nibble

Nibble is a content management system you run as your whole application: clone it, install it, and make the site
yours through your own theme, your own schema and your own settings. Upgrades arrive as releases you merge.

Content is defined as code. Collections, taxonomies, blueprints, globals, navigation and forms are YAML, read in
three layers — Nibble's, your theme's, then yours — and the entries and terms you edit are rows validated against
a blueprint. The public site is server-rendered from your theme; the control panel is where people work.

## Where to start

| If you are | Read |
|---|---|
| running a site | [Running a site](users/index.md) |
| writing and publishing | [Editing content](editors/index.md) |
| building the site's looks | [Building a theme](themes/index.md) |
| extending Nibble | [Extending Nibble](extensions/index.md) |
| working on Nibble itself | [Developing Nibble](developers/index.md) |

## What belongs to you

**Everything under `lib/nibble/` is Nibble's. Everything else is yours** — including `app/`, so your own models,
controllers and jobs sit where a Rails application puts them.

To change one of Nibble's files, `bin/rails nibble:eject <path>` copies it where yours is found first and records
that you now maintain it. `bin/rails nibble:check` then tells you when the original moves on, and reports anything
of Nibble's you changed without ejecting — the files an upgrade will stop on.

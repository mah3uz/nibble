---
title: Invariants
description: The rules the code holds to, and what enforces them.
order: 2
---

# Invariants

Each of these has a test. They are the things that are cheap to hold and expensive to discover you have broken.

## Database portability

No SQLite-specific SQL outside `Nibble::Search`, which wraps FTS5, and the snapshot service. JSON columns use the
Rails `json` type, never raw `json_extract` in app code. A test scans `lib/` for SQLite keywords and fails on
anything not on its allowlist.

## Rich-text safety

Themes output rich text as HTML, so it is rendered **server-side** from the stored JSON by `RichText::Renderer`
and must pass `RichText::Sanitizer`'s allowlist. Uploaded SVGs go through `Nibble::Assets::SvgSanitizer`. Tests
prove `script`, `on*` attributes and `javascript:` URLs are stripped.

## Redirects are single-hop

Chains are repointed when a redirect is saved, so a URL redirected twice still arrives in one hop.

## Content import is idempotent

Package import and content migrations can be re-run safely. A migration that has already moved data does nothing
the second time.

## Versioned contracts

`Nibble::SCHEMA_FORMAT`, `THEME_API_VERSION` and `CONTENT_FORMAT_VERSION` in `lib/nibble.rb` change only with a
migration or an upgrade path. A theme pins the theme API (`nibble: '^1'`), not the application version, so a
theme does not break because Nibble reached 2.0.

## Breaking changes ship switched off

New behaviour is behind `load_defaults` in `config/nibble.yml`. Taking a release never changes how a site behaves
on its own.

## The ownership line

Nothing Nibble ships is written outside `lib/nibble/` and the files it generates at install. `bin/rails
nibble:check` reports any of Nibble's files a site changed or deleted without ejecting.

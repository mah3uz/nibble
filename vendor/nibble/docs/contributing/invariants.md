---
id: contributing-invariants
title: Invariants
description: The rules Nibble's codebase holds to, why each exists, and the tests that enforce them.
order: 2
---

# Invariants

These are the rules the codebase holds to. **Each has a test**, because a rule nobody enforces is a preference.

After reading this guide, you will know the rules a change must not break, and why each one exists.

They are collected here rather than left in the code they constrain, because most of them are about what must *not*
happen — and the place someone would break one is rarely the place the rule is written.

## 1. Database portability

No SQLite-specific SQL outside `Nibble::Search`, which wraps FTS5, and the snapshot service. JSON columns use the
Rails `json` type, never raw `json_extract` in application code. A test scans `lib/` for SQLite-only keywords and
fails on anything not on its allowlist.

## 2. Rich-text safety

Themes output rich text as HTML, so it is rendered **on the server** from the stored structure by
`RichText::Renderer`, and must pass `RichText::Sanitizer`'s allowlist. Markdown has its own sanitizer. Uploaded SVGs
go through `Nibble::Assets::SvgSanitizer`. Tests prove `script` elements, `on*` attributes and `javascript:` URLs are
stripped.

> [!CAUTION]
> A change that lets markup reach a theme without passing a sanitizer is a stored cross-site scripting hole on every
> site running Nibble. It does not merge.

## 3. Redirects are single-hop

Chains are repointed when a redirect is saved, so an address redirected twice still arrives in one hop.

## 4. Imports are idempotent

Package imports and content migrations can be run again safely: a migration that already moved the data does nothing
the second time. That is what makes a failed deploy safe to retry.

## 5. Versioned contracts

`Nibble::SCHEMA_FORMAT`, `THEME_API_VERSION` and `CONTENT_FORMAT_VERSION` in `vendor/nibble/lib/nibble.rb` change only
with a migration or an upgrade path. A theme pins the theme API (`nibble: '^1'` in `theme.yml`), not Nibble's version,
so a theme does not break because Nibble reached 2.0.

## 6. The ownership line

Nothing Nibble ships is written outside `vendor/nibble/` and the files it generates once at install. `nibble:check`
warns about any of Nibble's files a site changed or deleted without ejecting.

This is what everything about upgrades rests on: a site can take a release without reading it, because a release
cannot have touched anything the site owns.

## 7. Files stay inside site/content/

A collection [written as files](../modelling/content-as-files.md) names a folder inside `site/content/` and nothing
else. An absolute path, or one containing `..`, is refused by the schema, so a schema file cannot point a reader at the
rest of the application. Only images are published from it, under digested names.

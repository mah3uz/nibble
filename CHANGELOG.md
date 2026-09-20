# Changelog

What changed for a site running Nibble. Anything that needs you to act has an **Upgrade** note; releases without
one are safe to take as they come.

Versions are ordered but not promises: while Nibble is `0.x`, anything can change between releases. Themes pin the
theme API (`nibble: '^1'` in `theme.yml`), not this number.

## Unreleased

## 0.1.0 — 2026-09-20

### Added

- `schema/` holds a site's own collections, blueprints, taxonomies, globals, navigation and forms. It is read after
  Nibble's and after the theme's, so a file here replaces one of ours whole.
- `site/` holds a site's control panel changes: `site/pages/<same path as ours>.vue` replaces one of our screens,
  `site/slots/{Logo,SidebarExtra,Scripts}.vue` replace parts of the chrome, and `site/initializers/*.rb` runs at
  boot.
- `bin/rails nibble:eject PATH` copies one of our files into `site/` and records it in `.nibble/ejected.yml`.
- `bin/rails nibble:check` reports ejected copies whose original has since changed, and files of ours edited in
  place rather than ejected.
- `bin/rails nibble:check --support` prints an install summary to paste into an issue.
- Load hooks `:nibble_entry`, `:nibble_term` and `:nibble_asset`, so a site adds behaviour without reopening our
  classes.
- `Gemfile.local` for a site's own gems.
- `config/nibble.yml` accepts `load_defaults`, which is how new behaviour gets turned on — never by upgrading.
- A licence: MIT (`LICENSE`). Use it, change it, sell it, rebrand the control panel; keep the copyright notice
  with copies. No warranty, no support promise.

### Changed

- Passwords must be at least 12 characters and mix lower case, upper case, a number and a symbol. The rule is on
  the model, so the control panel, password resets, invitations and the installer all apply it.
  **Upgrade:** existing passwords keep working; the rule applies the next time one is set. If you seed an
  administrator with `ADMIN_PASSWORD`, that value must now satisfy it.

- Every setting has a default in code, so `config/nibble.yml` can be absent or partial.
- Reserved paths are a floor a site adds to rather than a list it replaces: `/admin` can no longer be claimed by an
  entry.
- `config/routes.rb` belongs to the site. Nibble's routes are drawn before and after it.
- Nibble's migrations live in `lib/nibble/db/migrate`, leaving `db/migrate` and `db/schema.rb` to the site.

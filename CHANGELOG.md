# Changelog

What changed for a site running Nibble, under **What's new**, **What's fixed**, **Changed** and **Security**.
Anything that needs you to act has an **Upgrade** note; releases without one are safe to take as they come. A
release whose database migrations cannot be undone says so in its entry, so you know the snapshot is the only way
back. The control panel shows these same notes, read from `docs/releases.json`, which a release generates from
this file.

Versions are ordered but not promises: while Nibble is `0.x`, anything can change between releases. Themes pin the
theme API (`nibble: '^1'` in `theme.yml`), not this number.

## Unreleased

## 0.4.0 — 2026-09-21

## What's new

- `bin/rails nibble:generate:view NAME --collection=posts` writes a view and its query sidecar into your own
  theme, typed for that collection's records, and says how to wire it up. It refuses to write into Nibble's
  theme, which is what `nibble:generate:theme` is for.

## 0.3.0 — 2026-09-21

## What's new

- `bin/rails nibble:generate:theme HANDLE` copies the starter theme into `themes/HANDLE`, names it as this site's
  theme and leaves ours alone, so a site never edits `themes/crumbs` to change how it looks.

## What's fixed

- The asset build ignored the theme named in `config/nibble.yml` and always bundled `themes/crumbs`, so a site
  with its own theme edited `.vue` files that were never built — silently, with nothing to see in any log. The
  build now resolves the theme the way the rest of Nibble does: your settings first, `NIBBLE_THEME` second.
- An upgrade stopped partway through on any site with its own theme or its own npm packages: `npm ci` refuses a
  lockfile that is not exactly ours.
- `nibble:generate:theme` registers the new theme with npm, so a later `npm ci` — in your own CI, or a container
  build — doesn't fail naming a workspace nothing told you about.
- A theme view that throws while rendering on the server now says which view and which URL in the log, instead of
  an anonymous stack trace. Vue drops only the piece that threw, so the page is otherwise served as normal.
- `bin/rails nibble:upgrade` writes `db/schema.rb` when there isn't one, so taking 0.2.1 — which stopped shipping
  ours — leaves a site with its own. **Upgrade:** 0.2.1 said to run `bin/rails db:prepare` for this; that only
  writes the file when there is something to migrate. If you have no `db/schema.rb`, run
  `bin/rails db:schema:dump` once, or take this release and it is written for you.

## 0.2.1 — 2026-09-21

## What's fixed

- The Updates screen showed only "Up to date" when you were already on the newest release, hiding every release's
  notes. It now lists them whatever version you are on, with the one you are running marked.

## Changed

- `package-lock.json` is shared, not ours alone: a site with its own theme or packages has to change it. An
  upgrade now rebuilds it with `npm install` rather than installing from it, so a merged lockfile repairs itself.
  **Upgrade:** if git reports a conflict on it, take either side and run `npm install` — the result is the same
  either way, and commit it.
- `db/schema.rb` is yours, and Nibble no longer ships one. It is generated from migrations, so two copies of it —
  ours and yours — conflicted on every upgrade that carried a migration, on a file neither of us edits by hand.
  **Upgrade:** the merge removes our copy. Run `bin/rails db:prepare` to regenerate yours, then commit it. If git
  reports a conflict on it instead, keep your side and run the same command.

## 0.2.0 — 2026-09-21

## What's new

- `bin/nibble-upgrade` takes this site to a release: it snapshots the database, gates on the incoming release's
  requirements, merges, installs dependencies and migrates. It runs on a workstation only.
- The upgrade offers to re-render the files you own that we generate, and reports what changed in our copy of
  anything you ejected.
- **Updates** in the sidebar: releases newer than the one you are running, what each one changed, and the command
  that takes it, with a count on the menu item that turns red when one of them is a security fix. A daily
  background check remembers the count; the page itself reads the file again when you open it, so no other page
  ever waits on it and there is nothing to set up. Nothing about your site is sent, and a switch on that screen
  stops the checks entirely.
- Settings a person changes in the control panel are kept in a `settings` table, separate from `config/nibble.yml`,
  which stays a file you edit by hand.

## Changed

- The first administrator is made by asking, not by environment variables: `bin/rails nibble:admin:create` asks
  for a name, email address and password, and refuses a password the rules reject. `ADMIN_EMAIL`,
  `ADMIN_PASSWORD` and `ADMIN_NAME` no longer do anything — `db:seed` seeds roles and tells you to run the
  command.
- `.nibble/install.yml` now records the answers the install was given, which is what lets an upgrade re-render
  your settings without asking again. Installs made before this keep working; the upgrade says it cannot
  re-render them.

## 0.1.0 — 2026-09-20

## What's new

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

## Changed

- Passwords must be at least 12 characters and mix lower case, upper case, a number and a symbol. The rule is on
  the model, so the control panel, password resets, invitations and the installer all apply it.
  **Upgrade:** existing passwords keep working; the rule applies the next time one is set. If you seed an
  administrator with `ADMIN_PASSWORD`, that value must now satisfy it.

- Every setting has a default in code, so `config/nibble.yml` can be absent or partial.
- Reserved paths are a floor a site adds to rather than a list it replaces: `/admin` can no longer be claimed by an
  entry.
- `config/routes.rb` belongs to the site. Nibble's routes are drawn before and after it.
- Nibble's migrations live in `lib/nibble/db/migrate`, leaving `db/migrate` and `db/schema.rb` to the site.

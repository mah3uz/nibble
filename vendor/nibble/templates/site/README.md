# Your site

This directory is yours, and an upgrade never touches what you put in it:

- `schema/` — your collections, taxonomies, blueprints, globals, navigation and forms
- `content/` — content kept as files
- `themes/<name>/` — your own theme; one of Nibble's, such as `crumbs`, needs no copy here
- `cp/` — your control panel overrides

Your own Ruby lives where Rails puts it — `app/`, `config/initializers/`, `test/` — and is yours as well. So is every
Rails setting in `config/`: the lines Nibble needs there are marked `# Nibble:` with the reason, and
in production, Nibble names any it relies on and no longer finds, at boot and in `bin/rails nibble:check`.

## Schema

Schema is read in three layers — Nibble's own, then your theme's, then `site/schema/` — and the last one to define a
handle wins, so a file here named after one of Nibble's replaces it. It uses the same layout as Nibble's:
`collections/<handle>.yml`, `taxonomies/`, `blueprints/collections/<collection>/<handle>.yml`, `fieldsets/`,
`globals/`, `navigation/`, `forms/`.

**An override replaces the whole file**, not the keys in it: start from a copy of the one you are replacing. To
remove one of Nibble's collections instead, list it under `disable:` in `config/nibble.yml`. Run
`bin/rails nibble:check` after editing anything here.

## Content as files

A collection whose pages are written by hand names a folder in `site/content/` with `files: <folder>`. The folder is
the collection: a file is a page, a folder's `index.md` is the page its files sit under, and frontmatter becomes
fields. Every page needs an `id:` that never changes. Pages written this way are read-only in the control panel, and
nothing outside `site/content/` can be named by `files:`.

## Control panel overrides

To change one of Nibble's control panel screens, copy it to the same path under `site/cp/` and edit the copy:

```
vendor/nibble/frontend/nibble-admin/pages/admin/entries/Edit.vue   ->   site/cp/pages/admin/entries/Edit.vue
```

Yours is loaded instead of ours. Nothing else changes, and Nibble's file stays where it is.

Use `bin/rails nibble:eject` rather than copying by hand: it puts the file in the right place and records that you
now maintain it, so upgrades can tell you when the original changed.

**An override is a copy, not a patch.** Once a file is here it stops getting our improvements and bug fixes, so
prefer the supported extension points first and eject only when there is no other way.

## Your own Ruby

In an initializer of your own in `config/initializers/`, subscribe to Nibble's load hooks rather than reopening its
classes:

```ruby
ActiveSupport.on_load(:nibble_entry) do
  def reading_minutes = (data["body"].to_s.split.size / 200.0).ceil
end
```

Hooks are published for `:nibble_entry`, `:nibble_term` and `:nibble_asset`.

## Slots

Some parts of the control panel take a replacement without ejecting anything. Drop a component at
`site/cp/slots/<Name>.vue` and it is used instead of ours:

| Slot | Replaces |
|---|---|
| `Logo.vue` | the mark in the control panel header |
| `SidebarExtra.vue` | empty space at the bottom of the sidebar |
| `Scripts.vue` | nothing — a place to add your own scripts or widgets to every control panel page |

Slots survive upgrades, so prefer one over ejecting the whole screen.

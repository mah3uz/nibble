---
name: nibble-extending
description: Extend a Nibble site with its own Ruby, Control Plane changes, events and integrations, without touching Nibble's files. Use when asked to add behaviour to a Nibble site beyond its schema and theme.
---

# Extending a Nibble site

A site is a complete Rails application. Everything under `vendor/nibble/` is Nibble's and each upgrade replaces it
whole; an upgrade refuses to run while one of those files has been changed in place. Everything else — `app/`,
`config/`, `lib/`, `db/migrate/`, `test/`, `site/`, the `Gemfile` — is the site's.

## Never edit `vendor/nibble/`

`where_is <file, class or screen>` says whose something is and which of these to use instead:

| To change | Use |
|---|---|
| schema | the same handle in `site/schema/` |
| the theme | a theme of the site's own in `site/themes/` |
| a Control Plane screen | `eject` it (copies it to `site/cp/pages/`, recorded in `config/nibble.yml`) |
| the Control Plane's logo, sidebar or scripts | `site/cp/slots/Logo.vue`, `SidebarExtra.vue`, `Scripts.vue` |
| a record's behaviour | a load hook: `ActiveSupport.on_load(:nibble_entry) { … }` (`:nibble_term`, `:nibble_asset`) |
| reacting to content changes | `Nibble::Events.subscribe("record.published", async: true) { … }` in an initializer |
| a form that runs Ruby | `Nibble::Forms.register_handler` |
| telling another system | a webhook, set up in the Control Plane |
| gems | the site's `Gemfile`, below `eval_gemfile "vendor/nibble/Gemfile"` |

Don't reopen Nibble's classes (`class Nibble::Records::Entry` in your file); load hooks exist so that doesn't break
on the next release. `check` reports Nibble files changed in place.

## Changing content from Ruby

Every change goes through `Nibble::Lifecycle.call(record, action, attrs, actor:)`. `actor:` is required: the user
making the change, or `Nibble::Principal.system` for the site's own jobs and scripts. It checks that actor's
permissions, keeps revisions, and publishes events. Never write content rows directly.

## Code of the site's own

- Models, jobs, mailers and controllers in `app/`; settings in `config/initializers/`.
- Tests in `test/`, Minitest: `run_tests` returns failures as data. Name a test for the rule it protects.
- `lint` with `ruby` before finishing.

Guides: `extending/hooks.md`, `extending/control-plane.md`, `extending/management-api.md` — `read_doc` or
`search_docs`.

---
title: Seams
description: Adding behaviour without touching Nibble's files.
order: 1
---

# Seams

Each of these lets a site add something of its own where Nibble will keep finding it, so an upgrade never
conflicts with what you added.

## Your own Ruby

`site/initializers/*.rb` load after Rails' own initializers. This is where the rest of the seams are wired up.

## Load hooks

```ruby
# site/initializers/entries.rb
ActiveSupport.on_load(:nibble_entry) do
  after_save :ping_our_index
end
```

`:nibble_entry`, `:nibble_term` and `:nibble_asset` run against the record class as it loads. Use them instead of
reopening the class: a reopened class works today and breaks quietly later, which is the failure these exist to
prevent.

## Events

Nibble publishes what happens — a record published, moved, deleted — through an outbox, and subscribers run
after the change is committed. Subscribing from a `site/initializers/` file is how a site reacts to content
changing without patching the thing that changed it.

## Control panel screens and chrome

- `site/pages/<same path as ours>.vue` replaces one screen. `bin/rails nibble:eject <path>` copies ours there as
  a starting point and records that you now maintain it.
- `site/slots/Logo.vue`, `SidebarExtra.vue` and `Scripts.vue` replace parts of the chrome without ejecting
  anything.

## Gems

`Gemfile.local` is read if it exists, so a site's own gems do not touch `Gemfile`.

## Webhooks

For reacting from somewhere else entirely, **Webhooks** in the control panel posts signed payloads on content
events, with deliveries and retries visible.

## What does not exist yet

A plugin API: something installable that registers fieldtypes, screens and widgets together.
`bin/rails nibble:generate:plugin` refuses and says so. The fieldtype contract and the form handler seam in the
code are the likely shape of it.

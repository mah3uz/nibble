---
title: Extending Nibble
description: The seams a site can add behaviour through today.
order: 4
---

# Extending Nibble

Nibble has no plugin API yet. What it does have is a set of seams a site can use without touching Nibble's own
files, which means an upgrade never conflicts with what you added.

| Seam | Use it for |
|---|---|
| `site/initializers/*.rb` | your own Ruby, loaded after Rails' initializers |
| Load hooks `:nibble_entry`, `:nibble_term`, `:nibble_asset` | adding behaviour to a record without reopening its class |
| `site/pages/<same path as ours>.vue` | replacing one control panel screen |
| `site/slots/{Logo,SidebarExtra,Scripts}.vue` | replacing part of the control panel's chrome |
| `Gemfile.local` | gems of your own |

See [Seams](seams.md) for each one with an example.

A fieldtype contract and a form handler seam exist in the code and are the likely shape of the plugin API when it
arrives. `bin/rails nibble:generate:plugin` refuses today, and says why.

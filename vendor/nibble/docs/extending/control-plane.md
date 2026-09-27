---
id: extending-control-plane
title: Customising the Control Plane
description: Change the Control Plane's logo, add to its sidebar and pages, or replace a whole screen — and keep
  getting Nibble's fixes.
order: 2
---

# Customising the Control Plane

Tidewater's editors wanted the Control Plane to feel like Tidewater's: its logo in the header, a link to the
product's status page in the sidebar. Neither needs a fork.

After reading this guide, you will know:

- How to replace parts of the Control Plane's chrome with slots.
- How to replace a whole screen, and what that costs.
- How to eject a screen, and know when Nibble's original changes.

## 1. Slots

Some parts of the Control Plane take a replacement without ejecting anything. Put a component at
`site/cp/slots/<Name>.vue` and it is used instead of Nibble's:

| Slot | Replaces |
|---|---|
| `Logo.vue` | the mark in the Control Plane's header |
| `SidebarExtra.vue` | the empty space at the bottom of the sidebar |
| `Scripts.vue` | nothing — a place for your own scripts or widgets on every Control Plane page |

```vue
<!-- site/cp/slots/SidebarExtra.vue -->
<template>
  <a href="https://status.tidewater.example" class="px-3 text-sm text-gray-500">Product status ↗</a>
</template>
```

> [!TIP]
> Slots survive every upgrade untouched. Prefer one over replacing a whole screen whenever it will do.

## 2. Replacing a screen

Every Control Plane screen is a Vue page in `vendor/nibble/frontend/nibble-cp/pages/`. Put a file at the same path
under `site/cp/pages/` and it is used instead:

```
vendor/nibble/frontend/nibble-cp/pages/cp/dashboard/Index.vue    Nibble's
site/cp/pages/cp/dashboard/Index.vue                                yours, used instead
```

The page receives the same props from the same controller, so it can show them differently — but it cannot ask for
more.

## 3. Ejecting a screen

Starting a replacement from a blank file is rarely what you want. Eject copies Nibble's page to the right place and
records that you took it:

```sh
bin/rails nibble:eject vendor/nibble/frontend/nibble-cp/pages/cp/dashboard/Index.vue
```

```
ejected vendor/nibble/frontend/nibble-cp/pages/cp/dashboard/Index.vue
     to site/cp/pages/cp/dashboard/Index.vue
! site/cp/pages/cp/dashboard/Index.vue is yours now: it stops following Nibble's copy, including fixes. bin/rails nibble:check reports when the original changes.
```

The record is kept at the end of `config/nibble.yml`, under `ejected`: which file, where the copy went, and a checksum
of Nibble's original as you took it.

> [!WARNING]
> An ejected screen **stops receiving Nibble's fixes**. `nibble:check` tells you when the original changes, and
> `bin/rails nibble:upgrade` shows you exactly what changed in it, but carrying the change across is up to you.

Only Control Plane screens can be ejected. Everything else of Nibble's is changed through the seams in
[Ruby hooks and events](hooks.md), or by sending the change back — see [Contributing](../contributing/index.md).

### 3.1 Giving a screen back

When a release does what your copy did, take the release and drop your copy: delete the file under `site/cp/pages/` and
its entry under `ejected` at the end of `config/nibble.yml`.

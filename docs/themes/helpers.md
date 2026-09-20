---
title: Theme helpers
description: The @nibble components and composables a theme renders with.
order: 5
---

# Theme helpers

`@nibble` is the theme runtime: the few things every theme needs, so no theme writes them again.

```vue
<script setup lang="ts">
import { RichText, Image, Blocks, Pagination, SeoHead, useSite, useGlobals, useNavigation } from '@nibble'
</script>
```

| Import | Renders or returns |
|---|---|
| `RichText` | rich text, already rendered to sanitized HTML on the server |
| `Image` | an asset with the right preset, srcset and dimensions |
| `Blocks` | a replicator field, each set through `views/sets/<type>.vue` |
| `Pagination` | the links for a paginated query |
| `SeoHead` | title, description, canonical, Open Graph and structured data |
| `PreviewBar` | the bar shown when previewing a draft |
| `useSite`, `useGlobals`, `useNavigation`, `useLocale` | shared props, without passing them down |
| `useNibbleForm` | posting a form and handling its errors |

## Rich text is HTML, and already safe

Rich text is stored as structured JSON and rendered to HTML **on the server**, through an allowlist that strips
`script`, `on*` attributes and `javascript:` URLs. Themes render the result with `RichText`; uploaded SVGs are
sanitized on upload. Do not render a theme's own HTML through `v-html`.

## Images

`Image` takes an asset and a preset name. Presets are named sizes in `config/nibble.yml` — `card`, `hero`,
`content`, `og` out of the box, and any you add — served through Nibble's own transform endpoint and cached by
content, so a URL never goes stale.

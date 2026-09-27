---
name: nibble-theming
description: Build or change a Nibble site's theme — views, layouts, query sidecars, blocks and components — and check the result. Use when asked to change how a Nibble site's pages look or what they show.
---

# Theming a Nibble site

A theme is a folder of Vue single-file components rendered on the server through Inertia. The active theme is named
in `config/nibble.yml` (`theme:`), then `NIBBLE_THEME`, and is looked for in `site/themes/<name>/`, then
`vendor/nibble/themes/<name>/`.

## Whose files these are

- Change only a theme under `site/themes/`. A theme under `vendor/nibble/themes/` (`crumbs`) is Nibble's and an
  upgrade replaces it. To change it, start a theme of the site's own: `bin/rails nibble:generate:theme <name>`,
  which copies `crumbs` into `site/themes/<name>/` and makes it the site's.
- `where_is <view or component>` says whose a file is. `bin/rails nibble:generate:view <name> --collection=<handle>`
  starts a view with its props typed.

## The pieces

| Path in the theme | Is |
|---|---|
| `views/<name>.vue` | a page kind: `posts/show`, `posts/index`, `pages/show`, `search`, `errors/404` |
| `views/<name>.yml` | the view's query sidecar: each key becomes a prop |
| `views/sets/<set>.vue` | one block of a replicator field, given the set's fields as props |
| `layouts/<name>.vue` | the frame around a page; `default` unless a collection names another |
| `components/` | the theme's own components |
| `styles/theme.css` | the theme's stylesheet (Tailwind) |
| `schema/` | the theme's schema layer, read after Nibble's and before the site's |

Which view renders a request: the entry's own template, then its blueprint's, then its collection's, then
`default`. A collection's index uses `index_template`, then `collections/index`. Nothing matches → `errors/404`.

## Rules that keep a theme correct

1. **A view never fetches.** No `fetch`, no API calls. Put what it needs in its sidecar so Nibble knows what the page
   depends on and can clear its cache precisely.
2. **Declare URL parameters** a sidecar reads under `params:`; undeclared ones are ignored.
3. **Filter only on columns and relationship fields** (`status`, `published_at`, `slug`, `entries`/`terms` fields);
   an ordinary field isn't filterable.
4. **Type props from `@site/types`**: `defineProps<ViewProps['posts/show'] & { page: PostsPost }>()`. A field that
   doesn't exist is then a type error, not a broken page.
5. **Keep `<SeoHead />` in every layout.**
6. **No browser globals while rendering on the server.** `window`, `document` and `localStorage` belong in
   `onMounted`. Server rendering drops the subtree that fails and the page hydrates with mismatches.
7. **Rich text** is `<RichText :value="page.body" />`; images `<Image :image="…" sizes="…" />`; blocks
   `<Blocks :blocks="page.blocks" />` — all from `@nibble`.

## A sidecar

```yaml
# views/posts/show.yml
related:
  from: entries:posts
  where: { topics: { in: $entry.topics } }
  not: { id: $entry }
  limit: 3
```

Sources: `entries:<collection>`, `terms:<taxonomy>`, `search:<index>`, `form:<handle>`. Variables: `$entry`,
`$term`, `$set`, `$params.<name>`, `$now`, `$locale`. `paginate: { per_page: 12 }` makes the prop `{ data, meta }`.

## The loop

1. Change the view, layout, component or sidecar.
2. `render` a path that uses it: read `view` and `layout` (the files that answered), `props`, and `error`.
3. `run_query_sidecar` when only the data is in question.
4. `logs` with `kind: ssr` or `browser` if the page renders but misbehaves; `last_error` for the latest failure.
5. `lint` with `tool: types`, then `tool: js`, then `run_tests`.

`search_docs` answers anything else from the docs for the installed version; the theming guides are
`theming/views.md`, `theming/queries.md` and `theming/components.md`.

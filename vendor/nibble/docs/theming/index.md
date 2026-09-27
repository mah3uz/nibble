---
id: theming
title: Building a theme
description: What a theme is, what its directory holds, how a request becomes a rendered page, and how to work on
  one day to day.
order: 3
---

# Building a theme

A theme is everything a visitor sees: layouts, views, components and styles, plus the schema it needs to render.
This guide introduces Tidewater's theme and how Nibble uses it.

After reading this guide, you will know:

- What a theme holds, and how to start one of your own.
- How a request becomes a rendered page, and which parts of that are yours.
- How the active theme is chosen.
- What to expect from the development loop.

## 1. Starting a theme

Every site starts with `crumbs`, the theme Nibble ships. It is Nibble's, and an upgrade replaces it, so the first
thing you do is copy it:

```sh
bin/rails nibble:generate:theme tidewater
```

That copies `vendor/nibble/themes/crumbs` to `site/themes/tidewater`, renames its npm package to
`@nibble-theme/tidewater`, registers it with npm and makes it the active theme in `config/nibble.yml`. Commit it with
`package-lock.json`.

> [!WARNING]
> Do not edit `vendor/nibble/themes/crumbs`. It is replaced on every upgrade, which refuses to go ahead while it is
> changed. Your theme is yours for good.

## 2. What a theme holds

```
site/themes/tidewater/
├── theme.yml          name, version, and the theme API it was written for
├── package.json       the theme's own npm dependencies
├── layouts/           the frame around a page — default.vue
├── views/             one view per kind of page, each with an optional .yml query beside it
│   ├── sets/          one component per block in a replicator
│   └── errors/        404.vue and 500.vue
├── components/        your own components
├── lib/               your own TypeScript helpers
├── styles/            theme.css, built by Vite
└── schema/            collections, blueprints and so on this theme needs
```

The types generated from the schema are `site/types.d.ts`, imported as `@site/types`. Do not edit them.

```yaml
# site/themes/tidewater/theme.yml
name: Tidewater
handle: tidewater
version: 0.1.0
nibble: '^1'
description: Tidewater, a theme for Nibble.
```

`nibble: '^1'` pins the **theme API**, not Nibble's version. A theme written for theme API 1 keeps working however
many Nibble releases come out, and a site will not start with a theme built for a different one.

> [!IMPORTANT]
> A theme never ships content. It is layouts, views, components, styles and schema. Pages and posts belong to the
> site — in its database, or in a [content package](../running/content-packages.md) — so one theme can serve many
> sites without carrying any of them.

## 3. How a page is rendered

1. **Redirects** are checked first, from a cached table. A moved page costs one lookup.
2. **The URL is resolved** — to an entry, a file's page, a taxonomy term, a collection's or taxonomy's index, or
   nothing, which renders `views/errors/404.vue`.
3. **The view is chosen** — the entry's own template, its blueprint's, its collection's, or `default`.
4. **The view's query sidecar runs.** A `.yml` beside the view lists the extra content the page needs, and Nibble
   fetches it. See [Queries](queries.md).
5. **The view renders on the server** with Vue, inside its layout, and is hydrated in the browser. Visitors and
   search engines get finished HTML.
6. **The response is cached** against everything it used, so publishing any of it clears exactly the pages that
   depended on it.

Steps 3 to 5 are yours; the rest is Nibble's.

> [!NOTE]
> Because Nibble runs every query itself (step 4), it knows exactly what each page depended on. That is why a view
> never fetches its own data: a page that fetched for itself could not be cached precisely.

## 4. The active theme

The active theme is named by `theme:` in `config/nibble.yml`, or by the `NIBBLE_THEME` environment variable when
the file does not say. Without either, it is `crumbs`.

## 5. The development loop

`bin/dev` runs Rails, Vite and server-side rendering together. Saving an existing view, component, style, schema file
or content file shows up on the next reload.

> [!WARNING]
> Restart `bin/dev` after **adding** a view, a block or a layout, or after changing the active theme. New files
> are only picked up when the asset server starts; until then the browser console reports
> `Page not found: theme/<view>` and a new block renders nothing.

`npm run lint` checks your theme with ESLint, including that it imports only `@nibble`, `@theme`, relative paths
and its own dependencies, which is what keeps it swappable. `npm run format` lays it out with Prettier.

Theme dependencies are ordinary npm packages in the theme's own workspace:

```sh
npm install highlight.js -w @nibble-theme/tidewater
```

Commit the lockfile afterwards. It is shared with Nibble, and an upgrade rebuilds it rather than installing from
it, so a conflict there is harmless.

## 6. The guides in this section

| Guide | Covers |
|---|---|
| [Views and layouts](views.md) | which view renders which page, layouts, blocks and error pages |
| [Queries](queries.md) | the sidecar that fetches what a page needs |
| [Theme components](components.md) | rich text, images, blocks, pagination, SEO, menus and forms |
| [SEO, sitemaps and feeds](seo-and-feeds.md) | what search engines and feed readers receive |
| [The Content API](content-api.md) | reading the same content over HTTP |

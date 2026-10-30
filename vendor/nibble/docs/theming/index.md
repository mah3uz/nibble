---
id: theming
title: Building a theme
description: Where to find what you need to build a theme, how to start one, what its directory and theme.yml hold,
  how a request becomes a rendered page, and how to work on one day to day.
order: 3
---

# Building a theme

A theme is everything a visitor sees: layouts, views, components and styles, plus the schema it needs to render.
This guide introduces Tidewater's theme and how Nibble uses it.

After reading this guide, you will know:

- Which guide answers which question.
- How to start a theme and add a first view.
- What a theme holds, and every key of `theme.yml`.
- How a request becomes a rendered page, and which parts of that are yours.
- How the active theme is chosen, and what to expect from the development loop.

## Find what you need

| You want to | Read |
|---|---|
| show a list of posts, or any content a page does not own | [Queries](queries.md) |
| know what is in `page`, or what a field's value looks like | [Content in views](content-in-views.md) |
| choose which view renders a URL, or wrap pages in a layout | [Views and layouts](views.md) |
| draw rich text, an image, a block or a menu | [Theme components](components.md) |
| draw a form, or handle its errors and steps | [Forms](forms-in-your-theme.md) |
| style the site, support dark mode, add a font | [Styling and the page shell](styling-and-shell.md) |
| link between pages, add a tag to `<head>`, or run code only in the browser | [Styling and the page shell](styling-and-shell.md#4-links) |
| highlight code | [Styling and the page shell](styling-and-shell.md#6-highlighting-code) |
| set a page's title, social image or sitemap entry | [SEO, sitemaps and feeds](seo-and-feeds.md) |
| type a prop, or find a generated type name | [Content in views](content-in-views.md#6-the-generated-types) |
| read the content from another website or app | [The Content API](../extending/content-api.md) |

The theme Nibble ships, `crumbs`, is the working reference for all of it: its header, pagination, theme switch,
search page and contact form are in `vendor/nibble/themes/crumbs`. Read it beside these guides.

## 1. Starting a theme

Every site starts with `crumbs`, the theme Nibble ships. It is Nibble's, and an upgrade replaces it, so the first
thing you do is copy it:

```sh
bin/rails nibble:generate:theme tidewater
```

On a fresh checkout, run `bin/rails db:prepare` first: `nibble:check` reports a database that is not set up.

That copies `vendor/nibble/themes/crumbs` to `site/themes/tidewater`, rewrites `theme.yml` for the new handle, renames
its npm package to `@nibble-theme/tidewater`, makes it the active theme in `config/nibble.yml`, and runs
`npm install` so the lockfile knows the new workspace (`site/themes/*` is already a workspace of the site's
`package.json`). Commit the theme with `package-lock.json`. It does not touch `tsconfig.app.json`; see
[Type-checking](#type-checking-a-theme).

### What a theme minimally needs

- `theme.yml` with `name`, `handle` (the folder name), `version` and `nibble`. Section 2 lists every key.
- `layouts/default.vue`, the frame around every page.
- The views `nibble:check` requires: `pages/show`, `posts/show`, `posts/index`, `taxonomies/show`,
  `taxonomies/index`, `search`, `errors/404` and `errors/500`.
- `styles/theme.css`, the one stylesheet Nibble links.
- A `views/sets/<set>.vue` for every block set the schema defines, if any page uses blocks.

`nibble:check` names whatever is missing. A `package.json` is needed only if the theme has dependencies of its own.

### Starting by hand, or by copying crumbs

To start by hand, create `site/themes/<handle>/` with those files, set `theme: <handle>` in `config/nibble.yml`, and
run `npm install` if the theme has a `package.json`, so the workspace is registered.

To copy crumbs yourself, copy `vendor/nibble/themes/crumbs` and edit `theme.yml` and the package name as the
generator does. Either way, the copy brings crumbs' `schema/` with it, and that schema is the site's from then on:

- `forms/contact.yml`, a `contact` form that `views/about.vue` draws through `components/ContactForm.vue`. Remove
  the form, the `contact` query in `views/about.yml` and the component together, or adapt them. Besides the
  honeypot, it treats a message sent within 3 seconds of the page loading, or holding more than 2 links, as spam
  (`spam.min_seconds` and `spam.max_links`), so it works with no keys to set up. To stop determined bots, add
  `captcha: true` to its `spam` and the keys under **Integrations**; see
  [Spam](../modelling/form-spam-and-privacy.md#1-spam).
- `taxonomies/authors.yml` and `topics.yml`, with the `blueprints/` for pages and posts. The `about`, `home`,
  `posts/show`, `authors/show` and `topics/*` views read the authors and topics, so keep the schema or change those
  views with it.

### Does a theme outside the npm workspace work in production?

Yes, if it lives at `site/themes/<handle>`. The Vite build and the server-rendering build locate the theme by that
folder and point `@theme` at it; the workspace is not consulted. What the workspace does is install the theme's own
`package.json` dependencies (`npm ci` in the image installs only workspaces and the root). A theme outside it works as
long as it needs nothing beyond what the site's root `package.json` already installs; add any other dependency to the
root `package.json`.

From there, a first view of your own takes five steps:

1. Generate it with `bin/rails nibble:generate:view customers/show --collection=customers`. That writes the `.vue`
   and a query sidecar. See [Views and layouts](views.md#2-generating-a-view).
2. Add the `template:` line it prints to the collection, so entries use the view.
3. Open the sidecar and list what else the page needs. See [Queries](queries.md).
4. Read `page` and the query results in the template, typed by `@site/types`. See
   [Content in views](content-in-views.md).
5. Link to other pages with `<Link :href="item.uri">` and style with Tailwind classes. See
   [Styling and the page shell](styling-and-shell.md).

> [!WARNING]
> Do not edit `vendor/nibble/themes/crumbs`. It is replaced on every upgrade, which refuses to go ahead while it is
> changed. Your theme is yours for good.

## 2. What a theme holds

```
site/themes/tidewater/
├── theme.yml          name, version, and the theme API it was written for
├── package.json       the theme's own npm dependencies
├── layouts/           the frame around a page — default.vue is required
├── views/             one view per kind of page, each with an optional .yml query beside it
│   ├── sets/          one component per block in a replicator
│   └── errors/        404.vue and 500.vue
├── components/        your own components
├── lib/               your own TypeScript helpers
├── styles/            theme.css — the one stylesheet Nibble links, built by Vite
├── __tests__/         your own tests, if you write any
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

| Key | |
|---|---|
| `name` | required; the theme's display name |
| `handle` | required; must equal the theme's folder name |
| `version` | required; your theme's own version |
| `nibble` | required; the theme API it was written for, such as `'^1'` |
| `description` | optional; one line |
| `screenshot` | optional; a preview image of the theme, relative to its folder |
| `disable` | optional; schema from Nibble to switch off while this theme is active, as `kind/handle`, such as `navigation/footer` |

`nibble:check` reports a missing required key, an unknown key, a handle that does not match the folder, and a theme
API the site cannot run.

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
   depended on it. In development pages are not cached unless you turn caching on with `bin/rails dev:cache`, so an
   edited view shows on the next request.

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

Views, blocks and layouts you add while `bin/dev` runs are picked up without a restart. If the browser console
still reports `Page not found: theme/<view>`, or a new block renders nothing, restart `bin/dev`. Changing the active
theme always needs a restart.

`npm run lint` checks your theme with ESLint, and `npm run format` lays it out with Prettier. Lint rejects an import
of Nibble's internals (`@/*`, `~/*` and `vendor/nibble/frontend`), which is what keeps a theme swappable; `@nibble`,
`@theme`, `@site/types`, `vue`, `@inertiajs/vue3`, relative paths and your own dependencies are fine. To type-check
views, run `npx vue-tsc -p tsconfig.app.json --noEmit` (see below). `bin/rails nibble:check` reports a missing required view or
layout, a set with no view, and generated types that are out of date.

### Type-checking a theme

`npx vue-tsc -p tsconfig.app.json --noEmit` checks only the files `tsconfig.app.json` includes. The installer writes
it from `vendor/nibble/templates/tsconfig.app.json.erb`, and its `include` covers every theme in the site:

```json
"include": [
  "vendor/nibble/frontend/**/*.ts",
  "vendor/nibble/frontend/**/*.tsx",
  "vendor/nibble/frontend/**/*.vue",
  "site/themes/*/**/*.ts",
  "site/themes/*/**/*.vue",
  "site/types.d.ts"
]
```

A theme in another folder is not checked until you add its pattern here. `paths` also maps `@theme/*` to the theme
the installer was answered with; point it at your theme's folder if you started a different one.

Outside production, every response carries an `X-Nibble-Queries` header: the number of queries the page ran, which is
the quickest way to see a view's sidecar cost. A cached response carries `X-Nibble-Cache: hit`, and every response lists
what it depends on in `Surrogate-Key`.

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
| [Content in views](content-in-views.md) | the props a view receives, a record's shape, fieldtype values, generated types |
| [Queries](queries.md) | the sidecar that fetches what a page needs |
| [Theme components](components.md) | rich text, images, blocks, pagination, SEO and menus |
| [Forms in your theme](forms-in-your-theme.md) | drawing a form and every field, and everything `useNibbleForm` returns |
| [Styling and the page shell](styling-and-shell.md) | `theme.css`, Tailwind, dark mode, links, head tags, server rendering, code highlighting |
| [SEO, sitemaps and feeds](seo-and-feeds.md) | what search engines and feed readers receive |

Reading the same content over HTTP from another website or app is the [Content API](../extending/content-api.md), under
Extending Nibble. A theme does not use it.

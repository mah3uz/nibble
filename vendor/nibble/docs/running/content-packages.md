---
id: running-content-packages
title: Content packages
description: Keep a site's content as YAML in the repository — to seed a new server, move content between sites, or
  review it as a diff.
order: 6
---

# Content packages

A content package is a directory of YAML describing pages, posts, terms, globals, menus, redirects and asset details.
Keep one in the repository and it is how a new server — or a demo copy of the site — gets its content. Tidewater keeps
its package in `site/packages/default/`, apart from its theme, since a theme never ships content. Nibble never reads a
package on its own, so it can live anywhere except `site/content/`, which is for content written as files.

After reading this guide, you will know:

- What a package is for, and how it differs from content written as files.
- How to export one from a running site.
- The layout of a package, and what each file holds.
- How to import one safely, from a terminal or the Control Plane.

## 1. What it is for

A package is **a seed, not a source**. Importing one creates ordinary records, and afterwards the Control Plane edits
them like any other; nothing syncs back, and changing a page in the Control Plane does not change the file.

| | Content package | [Content as files](../modelling/content-as-files.md) |
|---|---|---|
| the files are | a starting point | the collection itself |
| after import | edited in the Control Plane | never edited in the Control Plane |
| brought in | once, by hand | every time the site starts |

Use a package to put content into a new database, to move content from one site to another, or to review a batch
of content as a diff before it goes in.

## 2. Exporting

```sh
bin/rails nibble:content:export site/packages/default
```

writes everything to `site/packages/default/`. Narrow it with `--collections=pages,posts`,
`--taxonomies=topics`, `--locales=en` or `--status=published`. Commit what it writes.

> [!TIP]
> Export after every batch of content changes worth keeping — a relaunched pricing page, a quarter's posts — so the
> repository always holds a recent copy that a demo or a new server can start from.

## 3. The layout

```
site/packages/default/
├── globals/site/en.yml
├── navigation/main/en.yml
├── collections/pages/en/home.yml
├── collections/pages/en/pricing.yml
├── collections/posts/en/late-invoices.yml
├── taxonomies/authors/en/priya-nair.yml
├── taxonomies/topics/en/cash-flow.yml
├── redirects.yml
└── assets.yml
```

A file's name is the record's slug, and its folder says which collection or taxonomy and which locale it belongs to.

A global is its fields:

```yaml
# site/packages/default/globals/site/en.yml
name: Tidewater
tagline: Invoicing that gets you paid
contact_email: hello@tidewater.example
```

A menu is a `tree`. A link is a `url`, an `entry` named as `<collection>/<slug>`, a `term` as `<taxonomy>/<slug>`, a
file as `asset: <folder>/<filename>`, or a site setting as `ref: global:<handle>.<field>`, so it survives the record
being given a new ID in a new database:

```yaml
# site/packages/default/navigation/main/en.yml
tree:
- entry: pages/pricing
  title: Pricing
- url: "/blog"
  title: Blog
- kind: heading
  title: Company
  children:
  - asset: legal/terms.pdf
    title: Terms
    new_tab: true
  - ref: global:site.careers_url
    title: Careers
    fields:
      badge: Hiring
      related:
      - pages/about
```

An item also carries its `kind`, `new_tab`, `hidden` and item `fields`, written as an entry's fields are, so a
relationship names records by key. An item that links to a
record the package and the site don't have is reported, and nothing is imported.

An entry is its fields, blocks included; `redirects.yml` and `assets.yml` are lists.

## 4. Importing

```sh
bin/rails nibble:content:validate site/packages/default    # check it, write nothing
bin/rails nibble:content:import site/packages/default
```

On a server:

```sh
bin/kamal app exec 'bin/rails nibble:content:import site/packages/default'
```

| Option | What it does |
|---|---|
| `--mode=create` | adds what is missing and leaves everything else alone — the default |
| `--mode=update` | also overwrites records that already exist with the package's version |
| `--dry-run` | lists what would be created (`+`) and updated (`~`), and writes nothing |
| `--webhooks` | delivers webhooks for what was imported |

Every field must exist in the blueprint and hold a value it accepts. The whole package is validated before anything
is written, so a typo stops the import rather than half-filling a database.

> [!CAUTION]
> `--mode=update` replaces what editors have changed since the package was made. Use it on a database you are
> happy to overwrite — a demo, a fresh copy — not on the live site.

A package can carry its images and files. Beside `assets.yml`, an `assets/` folder holds each file at the `path` its
row names:

```
site/packages/default/
├── assets.yml                  # - path: team/Priya Nair.JPG
└── assets/team/Priya Nair.JPG
```

An import uploads each such file before it creates entries and terms, but only when the site has no asset at that
folder and filename, so running it again uploads nothing. The row's details (title, alt text, focal point, tags)
are applied to the uploaded asset. `--dry-run` lists the uploads (`+ assets/team/Priya Nair.JPG`) and writes
nothing. A row with no file under `assets/` describes an asset that must already be on the site: `--mode=update`
refreshes its details and the import skips it otherwise, and a reference to an asset the site does not have fails
validation.

> [!NOTE]
> An upload stores the filename lowercased and made URL-safe, so `Team Photo (1).JPG` becomes `team-photo-1.jpg`.
> A package may write a reference either way: `team/Priya Nair.JPG` and `team/priya-nair.jpg` both find the stored
> asset. Exported paths are already in the stored form.

An import stores exactly what the package says. It does not fill in a blueprint's `default` values, because an
export leaves out empty fields and filling defaults would bring back a value an editor had cleared. A package
written by hand therefore states every value it wants.

### 4.1 From the Control Plane

**Utilities** has the same thing for people without a terminal: **export** downloads the site's content as a zip, and
**import** takes one, shows what it would create or change, and only writes when you confirm. Both need their own
permissions, and ask for your password again. The zip carries the `assets/` folder too, and a confirmed import uploads it the same way.

## 5. On a fresh install

`bin/rails nibble:install` offers Nibble's own example pages and posts, so a new site is not an empty screen. That is
Nibble's starter content, unrelated to your package; your package is never imported unless you ask.

> [!NOTE]
> A theme never ships content. A theme is layouts, views, components, styles and schema, so it can serve many sites
> without carrying any of them.

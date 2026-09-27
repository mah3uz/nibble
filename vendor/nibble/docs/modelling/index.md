---
id: modelling
title: Modelling content
description: What schema is, the three layers it is read in, where each file goes, and the commands that write and
  check it.
order: 2
---

# Modelling content

Schema is where you say what content exists. This guide covers the ideas every other modelling guide builds on.

After reading this guide, you will know:

- What schema describes, and why it is files rather than settings in a database.
- How the three layers of schema combine, and how to override one file.
- Where each kind of schema file goes.
- How to generate schema files and check them.

## 1. Content has a shape, and the shape is a file

Tidewater's blog posts each have a title, a body, an author, some topics and a publish date. That list — the
*shape* of a post — is schema. The posts themselves are content.

Nibble keeps the two apart on purpose:

| | Where it lives | Who changes it | How it ships |
|---|---|---|---|
| **Schema** — collections, blueprints, forms… | YAML files in the repository | a developer | in a commit, reviewed, deployed |
| **Content** — the posts, pages and terms | rows in SQLite | editors, in the Control Plane | the moment they publish |

Because the shape is a file, a new field is reviewed in a pull request, arrives on every environment at once, and
can be rolled back like any other change. Nobody clicks a field into existence on production and forgets to do the
same on staging.

> [!NOTE]
> There is one exception to "content is rows": a collection can be [written as files](content-as-files.md), like
> Tidewater's help centre. Its shape is still schema; its content is Markdown in `site/content/`.

## 2. The kinds of schema

| Kind | What it declares | Tidewater's |
|---|---|---|
| [Collection](collections.md) | a kind of content, and its URLs | `pages`, `posts`, `help` |
| [Blueprint](blueprints.md) | the fields one kind of entry or term has | `page`, `post`, `article` |
| Fieldset | a group of fields several blueprints import | Nibble's `seo` |
| [Taxonomy](taxonomies.md) | terms entries relate to | `authors`, `topics` |
| [Global](globals-and-navigation.md) | one set of site-wide fields | `site`, `seo`, `integrations` |
| [Navigation](globals-and-navigation.md) | a menu | `main`, `footer`, `help` |
| [Form](forms.md) | a public form and where submissions go | `demo` |

## 3. Three layers

Schema is read from three places, in order, and **the last to define a handle wins**:

1. **Nibble's own** — `vendor/nibble/core_schema/`: pages, posts, the SEO fieldset, the site, SEO and integrations
   globals, and the main and footer menus.
2. **The active theme's** — `site/themes/<theme>/schema/`: whatever the theme needs to render, such as the `authors` and
   `topics` taxonomies and richer page and post blueprints.
3. **The site's own** — `site/schema/`: anything specific to this site.

Tidewater's `help` collection exists only in `site/schema/`. Its `posts` collection is declared by Nibble and again in
`site/schema/`, and the one in `site/schema/` is the one that counts. The post *blueprint* comes from the theme, which
overrides Nibble's.

> [!IMPORTANT]
> An override **replaces the whole file**. It does not merge into the one it overrides. Tidewater's
> `site/schema/collections/posts.yml` repeats the route and template because, without them, the collection would have
> none.

To see the schema as Nibble sees it after all three layers:

```sh
bin/rails nibble:schema:show
```

> [!TIP]
> Put schema a theme needs to render in the theme, and schema that is about *this site's* content in `site/schema/`.
> Keep the pricing block in `site/themes/tidewater/schema/`, because the theme draws it, and the help centre
> in `site/schema/`, because it is Tidewater's content, not the theme's idea.

## 4. Where the files go

```
site/schema/
├── collections/help.yml
├── blueprints/
│   ├── collections/help/article.yml
│   └── taxonomies/topics/topic.yml
├── taxonomies/topics.yml
├── fieldsets/cta.yml
├── globals/company.yml
├── navigation/help.yml
├── forms/demo.yml
└── migrations/2026_10_01_rename_intro.yml
```

A blueprint lives under the collection or taxonomy it belongs to: `blueprints/collections/<collection>/<blueprint>.yml`.
Content migrations are covered in [Changing the schema](changing-schema.md).

## 5. Generating schema

Generators write a valid stub in the right place, so you never start from a blank file or a copy of Nibble's:

```sh
bin/rails nibble:generate:collection case_studies
bin/rails nibble:generate:taxonomy industries
bin/rails nibble:generate:blueprint case_studies/video
bin/rails nibble:generate:fieldset cta
bin/rails nibble:generate:global company
bin/rails nibble:generate:navigation help
bin/rails nibble:generate:form demo
```

`nibble:generate:collection case_studies`, for example, writes a dated collection at `/case-studies/{slug}` and a
blueprint with a single `body` field. Edit them from there.

> [!WARNING]
> Do not copy a file out of `vendor/nibble/core_schema/` to start one of your own unless you mean to override it. A
> copied file with the same handle *is* an override, and it stops following Nibble's version from then on.

## 6. Checking schema

```sh
bin/rails nibble:check
```

`nibble:check` reads every layer and reports every problem at once: a field type that does not exist, a
collection pointing at a template the theme does not have, a form with a bad address, generated TypeScript types
that are out of date. It also reports **content the schema no longer covers** — a field removed while entries still
hold values for it.

> [!TIP]
> When `nibble:check` says the types are out of date, run `bin/rails nibble:schema:types`. The generators refresh
> them for you; changing a view's sidecar or a blueprint by hand does not.

It runs before every deploy, and a deploy it refuses never goes live. Run it whenever you change anything under
`site/schema/`.

## 7. What's next

- [Collections](collections.md) — declaring Tidewater's blog and help centre.
- [Blueprints and fields](blueprints.md) — the landing page's blocks, and every fieldtype.

---
id: docs
blueprint: doc_index
order: 0
title: Nibble Guides
description: Everything you need to build, run and write a website with Nibble, told through one example — the
  marketing site of Tidewater, a small invoicing startup.
hero_heading: A CMS your repository owns.
hero_text: Declare your content's shape in files, keep the content in SQLite, and ship the whole site from one machine.
primary_label: Build your first site
primary_link: /docs/getting-started/tutorial
secondary_label: View the source
secondary_link: https://github.com/mah3uz/nibble
code_filename: schema/collections/posts.yml
code_filename_muted: site/themes/tidewater/views/posts/index.yml
code: |
  schema: 1
  title: Blog
  route: /blog/{slug}
  dated: true
  blueprints: [post]
  template: posts/show
  feed: true
links:
- title: Getting Started with Nibble
  link: /docs/getting-started/tutorial
  text: Build Tidewater's site from an empty directory — landing pages, a blog and a help centre — and deploy it.
- title: Modelling content
  link: /docs/modelling
  text: Collections, blueprints, taxonomies, globals, navigation and forms, and changing them safely.
- title: Content as files
  link: /docs/modelling/content-as-files
  text: Serve a folder of Markdown as a collection, with no database copy of it.
- title: Building a theme
  link: /docs/theming
  text: Views, layouts, query sidecars and the components every theme uses.
- title: Editing content
  link: /docs/editing
  text: Writing, publishing, assets, menus, forms and redirects in the Control Plane.
- title: Running a site
  link: /docs/running
  text: Configuration, people, deployment, backups and upgrades.
---

# Nibble Guides

These guides follow one site from an empty directory to production: the marketing site of **Tidewater**, a
small startup that sells invoicing software. Tidewater needs what most young companies need from a website —
landing pages that marketing can change without a developer, a blog, a help centre that lives beside the product's
code, and a form that books a demo.

Every guide uses that same site in its examples, so the collection you declare in one is the one you render in
the next.

> [!WARNING]
> **Nibble is in `alpha` and under heavy development.** Expect breaking changes often: settings, schema keys, commands
> and the theme API can change from one release to the next. Read the [changelog](../changelogs/index.md) before every upgrade.

> [!TIP]
> New to Nibble? Start with [Getting Started with Nibble](getting-started/tutorial.md). It builds the whole
> Tidewater site in one sitting, and every other guide goes deeper into one part of it.

## Start here

- [Start here](getting-started/index.md) — what Nibble is, who it suits, and how these guides are organised.
- [Getting Started with Nibble](getting-started/tutorial.md) — build Tidewater's site end to end.
- [Installing Nibble](getting-started/installing.md) — what your machine needs and every question the installer asks.

## Modelling content

- [Modelling content](modelling/index.md) — the three layers of schema, and the commands that write and check them.
- [Collections](modelling/collections.md) — kinds of content, and the URLs they live at.
- [Blueprints and fields](modelling/blueprints.md) — the form an editor fills in, and every fieldtype.
- [Taxonomies](modelling/taxonomies.md) — authors, topics and other terms entries relate to.
- [Globals and navigation](modelling/globals-and-navigation.md) — site-wide settings and menus.
- [Forms](modelling/forms.md) — the demo request form, from YAML to inbox and CRM.
- [Content as files](modelling/content-as-files.md) — Tidewater's help centre, written as Markdown.
- [Changing the schema](modelling/changing-schema.md) — renaming and removing fields once content exists.

## Building a theme

- [Building a theme](theming/index.md) — what a theme holds and how a page is rendered.
- [Views and layouts](theming/views.md) — which view renders which page, and the frame around it.
- [Queries](theming/queries.md) — asking for the content a page needs.
- [Theme components](theming/components.md) — rich text, images, blocks, pagination, SEO and forms.
- [SEO, sitemaps and feeds](theming/seo-and-feeds.md) — what search engines and feed readers receive.
- [The Content API](theming/content-api.md) — reading the same content from somewhere else.

## Editing content

- [Editing content](editing/index.md) — finding your way around.
- [Entries](editing/entries.md) · [Drafts and publishing](editing/publishing.md) · [Assets](editing/assets.md) ·
  [Navigation](editing/navigation.md) · [Form submissions](editing/form-submissions.md) ·
  [Redirects and SEO](editing/redirects-and-seo.md)

## Running a site

- [Configuration](running/configuration.md) · [Users and roles](running/users-and-roles.md) ·
  [Deploying](running/deploying.md) · [Backups](running/backups.md) · [Upgrading](running/upgrading.md) ·
  [Content packages](running/content-packages.md) · [Commands](running/commands.md)

## Extending and contributing

- [Extending Nibble](extending/index.md) — the seams a site adds its own behaviour through.
- [Contributing to Nibble](contributing/index.md) — working on Nibble itself.

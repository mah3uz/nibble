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
  text: Writing, publishing, assets, menus, forms, redirects, settings and your account in the Control Plane.
- title: Running a site
  link: /docs/running
  text: Configuration, people, deployment, backups, upgrades and the Control Plane's maintenance screens.
---

# Nibble Guides

These guides follow one site from an empty directory to production: the marketing site of **Tidewater**, a
small startup that sells invoicing software. Tidewater needs what most young companies need from a website —
landing pages that marketing can change without a developer, a blog, a help centre that lives beside the product's
code, and a form that books a demo.

Every guide uses that same site in its examples, so the collection you declare in one is the one you render in
the next.

> [!NOTE]
> **Nibble is in `beta`.** A release is meant to keep a working site working. Anything you need to do arrives as an
> **Upgrade** note in the [changelog](../changelogs/index.md), so read it before every upgrade.

> [!TIP]
> New to Nibble? Start with [Getting Started with Nibble](getting-started/tutorial.md). It builds the whole
> Tidewater site in one sitting, and every other guide goes deeper into one part of it.

## Start here

Pick the route that matches your job. Each is a short list, in reading order.

- **I write content.** You need nothing technical. [Editing content](editing/index.md), then
  [Write and organise pages and posts](editing/entries.md), then [Save, preview and publish](editing/publishing.md).
- **I administer the site from the Control Plane, without a terminal.**
  [Administering from the Control Plane](running/administering.md), then [Users and roles](running/users-and-roles.md).
- **I run the server.** [Installing Nibble](getting-started/installing.md), then
  [Configuration](running/configuration.md), [Deploying](running/deploying.md), [Backups](running/backups.md) and
  [Upgrading](running/upgrading.md).
- **I build the site.** [Getting Started with Nibble](getting-started/tutorial.md), then
  [Modelling content](modelling/index.md).
- **I build the theme.** [Building a theme](theming/index.md), then [Views and layouts](theming/views.md),
  [Content in views](theming/content-in-views.md), [Queries](theming/queries.md) and
  [Forms in your theme](theming/forms-in-your-theme.md).

## Getting started

- [Start here](getting-started/index.md) — what Nibble is, who it suits, and how these guides are organised.
- [Getting Started with Nibble](getting-started/tutorial.md) — build Tidewater's site end to end.
- [Installing Nibble](getting-started/installing.md) — what your machine needs and every question the installer asks.

## Modelling content

- [Modelling content](modelling/index.md) — the three layers of schema, and the commands that write and check them.
- [Collections](modelling/collections.md) — kinds of content, and the URLs they live at.
- [Blueprints and fields](modelling/blueprints.md) — the form an editor fills in, and how fields are laid out.
- [Taxonomies](modelling/taxonomies.md) — authors, topics and other terms entries relate to.
- [Globals and navigation](modelling/globals-and-navigation.md) — site-wide settings and menus.
- [Forms](modelling/forms.md) — the demo request form, from YAML to a page.
- [Content as files](modelling/content-as-files.md) — Tidewater's help centre, written as Markdown.
- [Form delivery](modelling/form-delivery.md) — emailing submissions and sending them to another system.
- [Form spam and privacy](modelling/form-spam-and-privacy.md) — bots, retention, encryption, limits and schedules.
- [Translating a form](modelling/form-translation.md) — a form's text per locale.
- [Every form key](modelling/form-keys.md) — each key a form file accepts.
- [Changing the schema](modelling/changing-schema.md) — renaming and removing fields once content exists.
- [Scheduled tasks](modelling/scheduled-tasks.md) — figures from an API, a feed of jobs, and your own Ruby, on a schedule.

## Building a theme

- [Building a theme](theming/index.md) — what a theme holds and how a page is rendered.
- [Views and layouts](theming/views.md) — which view renders which page, and the frame around it.
- [Content in views](theming/content-in-views.md) — what a page receives, and what each field looks like.
- [Queries](theming/queries.md) — asking for the content a page needs.
- [Theme components](theming/components.md) — rich text, images, blocks, pagination, SEO and menus.
- [Forms in your theme](theming/forms-in-your-theme.md) — drawing a form and every field.
- [Styling and the page shell](theming/styling-and-shell.md) — `theme.css`, Tailwind, dark mode, links and head tags.
- [SEO, sitemaps and feeds](theming/seo-and-feeds.md) — what search engines and feed readers receive.

## Editing content

- [Editing content](editing/index.md) — finding your way around.
- [Write and organise pages and posts](editing/entries.md)
- [Save, preview and publish](editing/publishing.md)
- [Add and edit categories and tags](editing/categories-and-tags.md)
- [Upload and manage images and files](editing/assets.md)
- [Restore something you deleted](editing/trash.md)
- [Build and arrange the site's menus](editing/navigation.md)
- [Change the site's settings](editing/site-settings.md)
- [Find and handle form submissions](editing/form-submissions.md)
- [Fix search results, share cards and broken links](editing/redirects-and-seo.md)
- [Add analytics and custom code](editing/analytics.md)
- [Connect an AI app and approve its changes](editing/ai-apps.md)
- [Set up your account and sign in safely](editing/your-account.md)

## Running a site

- [Running a site](running/index.md) — the guides, and a site's first week.
- [Configuration](running/configuration.md) — `config/nibble.yml`, environment variables and credentials.
- [Users and roles](running/users-and-roles.md) — adding people and deciding what each may do.
- [Administering from the Control Plane](running/administering.md) — what an administrator without a terminal can do.
- [Utilities](running/utilities.md) — cache, search, jobs, health, backups and the audit log.
- [Webhooks](running/webhooks.md) — telling another application when content changes.
- [Check messages](running/check-messages.md) — every message `nibble:check` prints, and how to fix it.
- [Deploying](running/deploying.md) — Kamal, secrets, the first deploy and what each deploy checks.
- [Backups](running/backups.md) — what is backed up, where, and how to restore it.
- [Upgrading](running/upgrading.md) — taking a release, and how to undo it.
- [Content packages](running/content-packages.md) — keeping content as YAML, and importing it.
- [Commands](running/commands.md) — every command in one place.
- [Agent access](running/agent-access.md) — deciding what connected AI apps may touch.
- [The nibble command](running/cli.md) — starting a site and working on content from a terminal.

## Extending Nibble

- [Extending Nibble](extending/index.md) — the seams a site adds its own behaviour through.
- [Ruby hooks and events](extending/hooks.md)
- [Customising the Control Plane](extending/control-plane.md)
- [Emails](extending/emails.md)
- [The management API and MCP](extending/management-api.md)
- [Building with an agent](extending/building-with-agents.md)
- [The Content API](extending/content-api.md) — reading the same content from somewhere else.

## Reference

- [Reference](reference/index.md) — look-up pages for blueprints and forms.
- [Fieldtypes and field options](reference/fieldtypes.md)
- [Validation rules](reference/validation.md)
- [Conditions](reference/conditions.md)

## Contributing

- [Contributing to Nibble](contributing/index.md) — working on Nibble itself.
- [Architecture](contributing/architecture.md)
- [Invariants](contributing/invariants.md)
- [Tests and checks](contributing/testing.md)
- [Releases](contributing/releases.md)

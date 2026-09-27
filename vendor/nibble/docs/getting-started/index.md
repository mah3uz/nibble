---
id: getting-started
title: Start here
description: What Nibble is, who it suits, the example site these guides build, and how the guides are organised.
order: 1
---

# Start here

This page introduces Nibble, the Tidewater site that runs through every guide, and the way the guides are laid out.

After reading this guide, you will know:

- What Nibble is, and what makes it different from a CMS you sign up for.
- Whether it suits the site you want to build.
- What Tidewater's site needs, and which guide covers each part of it.
- What you should already know before you start.

## 1. What Nibble is

Nibble is a content management system you run as your own application. You install it, answer a few questions,
and it becomes your site — your theme, your content, your server. There is no account to sign up for, no plan to
outgrow, and nothing phoning home.

People write in a **Control Plane** at `/cp`, and visitors see a **public site** rendered by your **theme**.
What sets Nibble apart is where the *definitions* live: the kinds of content you have, the fields each one carries,
the menus and forms — all of it is small YAML files in your repository. Change a file and the Control Plane
changes with it.

Under the hood it is a Rails 8 application. Pages are rendered with Vue 3 on the server through Inertia, so
visitors get finished HTML. Content, cache and job queue all live in SQLite, which makes a whole site one machine
and one database file.

> [!NOTE]
> You do not need to know Rails to run a Nibble site. You will edit YAML, write Vue components for your theme, and
> run commands. The [Contributing](../contributing/index.md) guides are the only ones that assume Ruby.

## 2. Is Nibble for you?

Nibble suits you if:

- You want a site you fully own, including its code and its data.
- You, or someone you work with, are comfortable with a terminal and a git repository.
- You would rather write a page's structure down once, reviewed in a pull request, than click it together again.

It is probably not for you if you want to upload files to shared hosting and run everything from a browser.

> [!IMPORTANT]
> Nibble expects a deploy step. Changing the *shape* of your content — a new field, a new collection, a new page
> template — is a code change that ships like any other. Changing the *content* itself happens in the control
> panel and needs no deploy.

## 3. Meet Tidewater

Tidewater is a fictional startup: four people, one product — invoicing software for small agencies — and a
website that has to do a lot of jobs. These guides build that website, and each part of it maps to a part of
Nibble:

| Tidewater needs | Nibble gives it | Guide |
|---|---|---|
| A home page, pricing and feature pages marketing can rearrange | the `pages` collection, built from blocks | [Blueprints and fields](../modelling/blueprints.md) |
| A blog with authors and topics | the `posts` collection and two taxonomies | [Collections](../modelling/collections.md), [Taxonomies](../modelling/taxonomies.md) |
| A help centre that ships with the product | a collection written as Markdown files | [Content as files](../modelling/content-as-files.md) |
| A "book a demo" form that reaches sales and the CRM | a form with email and API delivery | [Forms](../modelling/forms.md) |
| Its own look | a theme called `tidewater` | [Building a theme](../theming/index.md) |
| A site that finds its way into search results | SEO fields, sitemaps and an Atom feed | [SEO, sitemaps and feeds](../theming/seo-and-feeds.md) |
| One server, backed up nightly | Kamal and a nightly snapshot | [Deploying](../running/deploying.md), [Backups](../running/backups.md) |

Most guides put **you** in one role on that team. As the **developer**, you own the repository: the schema, the
theme, the deploys. As someone in **marketing**, you write in the Control Plane every day and never open a
terminal. Whoever writes the **help centre** works in Markdown, beside the product's code. Each section says which
role it is written for.

## 4. How these guides are organised

Each section is written for a different kind of work. You do not have to read them in order.

| Section | For | Start with |
|---|---|---|
| Start here | everyone, once | [Getting Started with Nibble](tutorial.md) |
| [Modelling content](../modelling/index.md) | you, as the developer | [Modelling content](../modelling/index.md) |
| [Building a theme](../theming/index.md) | you, as the developer | [Building a theme](../theming/index.md) |
| [Editing content](../editing/index.md) | you, writing in marketing | [Editing content](../editing/index.md) |
| [Running a site](../running/index.md) | you, keeping the site running | [Configuration](../running/configuration.md) |
| [Extending Nibble](../extending/index.md) | adding behaviour Nibble lacks | [Extending Nibble](../extending/index.md) |
| [Contributing](../contributing/index.md) | working on Nibble itself | [Contributing](../contributing/index.md) |

Every guide opens with what you will know after reading it, like this one, and uses callouts for the things worth
stopping on:

> [!NOTE]
> Background that helps but that you could skip.

> [!TIP]
> A shortcut or a better way of doing something.

> [!IMPORTANT]
> Something the rest of the guide depends on.

> [!WARNING]
> Something that will cause a problem if you ignore it.

> [!CAUTION]
> Something that can lose content or take a site down.

## 5. What you should know first

- **A terminal and git.** Installing, upgrading and deploying are commands, and your site is a repository.
- **A little YAML.** Every schema file is YAML; the guides show complete examples.
- **Some Vue**, if you are building a theme. The [Vue guide](https://vuejs.org/guide/introduction.html) is the
  place to start; Nibble's views are ordinary single-file components.

Ready? [Build Tidewater's site](tutorial.md).

---
id: running
title: Running a site
description: For whoever keeps the site alive — configuration, people, deploys, backups, upgrades and the commands
  behind them.
order: 5
---

# Running a site

This section is for you if you keep the site alive. At Tidewater that is the developer who also builds it — at a
bigger company it might be someone else entirely. It assumes a terminal and a server; it does not assume Ruby.

After reading this section, you will know how to configure a site, let people in, deploy it, back it up, take new
releases, and move its content around.

## 1. The guides

| Guide | Covers |
|---|---|
| [Configuration](configuration.md) | `config/nibble.yml`, environment variables, credentials, and which setting goes where |
| [Users and roles](users-and-roles.md) | adding people, what each role may do, and roles of your own |
| [Deploying](deploying.md) | Kamal, secrets, the first deploy, seeding a database, and what each deploy checks |
| [Backups](backups.md) | what is backed up, where, and how to restore it |
| [Upgrading](upgrading.md) | taking a release, what it asks, and how to undo it |
| [Content packages](content-packages.md) | keeping content as YAML, and importing it |
| [Commands](commands.md) | every command in one place |

## 2. A site's first week

1. **[Install it](../getting-started/installing.md)** and build it — [Getting Started](../getting-started/tutorial.md)
   is the whole of Tidewater's first day.
2. **[Configure it](configuration.md):** the URL, the time zone, image sizes, mail.
3. **[Deploy it](deploying.md)** and create the first administrator on the server.
4. **[Turn on offsite backups](backups.md)** before there is anything in it worth losing.
5. **[Let people in](users-and-roles.md)**, each with the smallest role that lets them work.
6. **[Check for updates](upgrading.md)** now and then, and take them one at a time.

## 3. What the site's repository holds

| Path | What it is | Whose |
|---|---|---|
| `vendor/nibble/` | the CMS itself, with its starter theme `crumbs` | Nibble's — replaced whole by each release |
| `site/themes/<yours>/` | your theme | yours |
| `site/schema/` | your collections, blueprints, forms, migrations | yours |
| `site/content/` | content kept as files | yours |
| `site/cp/` | Control Plane overrides | yours |
| `config/nibble.yml`, `config/deploy.yml`, `.env` | settings and the deploy | yours |
| `app/`, `config/`, `db/migrate/`, `test/`, `Gemfile` | your own Rails code, settings, tests and gems | yours |

> [!IMPORTANT]
> **Everything under `vendor/nibble/` is Nibble's; everything else is yours.** Keep to that and an upgrade never has
> anything to refuse. When you need to change something of Nibble's, see [Extending Nibble](../extending/index.md).

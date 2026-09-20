---
title: Installing
description: What you need, and what the installer asks.
order: 1
---

# Installing

Nibble is installed by cloning it. There is no gem and no npm package: the repository *is* the application, and
upgrades are releases you merge.

## What you need

git, Ruby, Node, npm, SQLite, libvips and ffmpeg. Ruby and Node versions are pinned in `mise.toml`, which
[mise](https://mise.jdx.dev) installs with `mise install`.

`install.sh` checks for all of them first and, if anything is missing, names every one at once with the command
to install it on your system. Nothing else is needed — SQLite holds the content, the cache and the job queue.

## Installing

```sh
./install.sh my-site
```

It clones Nibble into `my-site`, installs the gems and npm packages, and hands over to `bin/rails nibble:install`,
which asks:

- **Application name** — names the containers, image and volume when you deploy.
- **Public site URL** — used for canonical URLs, sitemaps, robots and links in mail.
- **Theme handle** — `crumbs` unless you have already made your own.
- **Whether you deploy with Kamal** — if so, it asks for hosts, servers, registry user and SSH user, and writes
  `config/deploy.yml` and `config/deploy.staging.yml`. Skip it and add them later with `--only=deploy`.
- **An administrator** — name, email address and password. This one is not optional: a site with no administrator
  has no way in. The password must be at least 12 characters with lower case, upper case, a number and a symbol.
- **Whether to import the theme's example content** — decline for an empty site.

It writes `config/nibble.yml`, `.env` and `config/master.key`, prepares the database, records the install in
`.nibble/install.yml`, and prints what to run next.

Everything it wrote is yours. Commit it.

## Afterwards

```sh
bin/rails nibble:check    # the schema, theme, roles and settings are sound
bin/dev                   # the site on http://localhost:3100, the control panel at /admin
```

Then [make it yours](../themes/index.md) with a theme of your own, and read [Settings](settings.md) for what else
you can set.

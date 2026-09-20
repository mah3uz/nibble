---
title: Commands
description: Every nibble:* command, and what it is for.
order: 8
---

# Commands

Every command lists its options with `--help`, for example `bin/rails nibble:content:import --help`.

## Checking

```sh
bin/rails nibble:check              # schema, theme, roles, settings, pending migrations, ejected files
bin/rails nibble:check --support    # a summary of this install to paste into an issue
bin/ci                              # every check Nibble runs on itself
```

## Making things

```sh
bin/rails nibble:generate:theme almanac
bin/rails nibble:generate:view guides/index --collection=guides
bin/rails nibble:generate:collection guides
bin/rails nibble:generate:taxonomy regions
bin/rails nibble:generate:blueprint guides/gallery
bin/rails nibble:generate:fieldset seo
bin/rails nibble:generate:global contact
bin/rails nibble:generate:navigation main
bin/rails nibble:generate:form enquiry
```

## People

```sh
bin/rails nibble:admin:create       # name, email, password and role, all asked for
```

## Content

```sh
bin/rails nibble:content:validate themes/crumbs/content
bin/rails nibble:content:import     # the active theme's package; --mode=update, --dry-run, --webhooks
bin/rails nibble:content:export tmp/package   # --collections=posts,pages --locales=en --status=published
bin/rails nibble:content:migrate --dry-run    # pending schema/migrations/*.yml
```

## Maintenance

```sh
bin/rails nibble:schema:types       # regenerate the theme's .nibble/types.d.ts
bin/rails nibble:search:rebuild
bin/rails nibble:assets:purge_unused          # --confirm, --older-than-days=1
bin/rails nibble:upgrade            # migrations, checks and the schema snapshot; runs before every boot
```

## Install and upgrade

```sh
./install.sh my-site
bin/rails nibble:install            # --defaults, --force, --only=deploy
bin/rails nibble:eject <path>       # take one of Nibble's files on
bin/nibble-upgrade [version]        # on a workstation, never a server
bin/nibble-release 0.6.0            # Nibble's own releases
```

## Development only

```sh
bin/rails nibble:dev:seed           # about 120 demo posts
RAILS_ENV=test bin/rails nibble:bench         # render and listing budgets; --posts, --requests
```

The playground at `/admin/nibble/playground` renders every blueprint plus one using all core fieldtypes, backed
by in-memory records. Development only.

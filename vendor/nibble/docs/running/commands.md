---
id: running-commands
title: Commands
description: Every nibble command and script in one place, grouped by what you are doing, with the options each takes.
order: 7
---

# Commands

Every command explains its own options:

```sh
bin/rails nibble:content:import --help
```

This page collects them by what you are doing.

## 1. Every day

```sh
bin/dev                          # the site on :3100, the Control Plane at /cp
bin/rails nibble:check           # schema, theme, roles, settings, migrations, ejected files
bin/rails nibble:build           # site/content and the schema, with no database; regenerates types
bin/rails nibble:version         # the release this site runs
bin/rails nibble                 # every command, under the release and what it runs on
```

`nibble:check` is the one to run when something is not behaving and you do not know why. It takes
`--allow-data-loss`, to report stranded content as warnings rather than failures, and `--support`, which prints a
summary of your install to paste into an issue.

## 2. Schema

```sh
bin/rails nibble:generate:collection customers
bin/rails nibble:generate:taxonomy industries
bin/rails nibble:generate:blueprint customers/video
bin/rails nibble:generate:fieldset cta
bin/rails nibble:generate:global company
bin/rails nibble:generate:navigation help
bin/rails nibble:generate:form demo
bin/rails nibble:schema:show                  # the schema after all three layers
bin/rails nibble:schema:types                 # regenerate site/types.d.ts
bin/rails nibble:schema:snapshot              # record field types as the baseline for nibble:check
```

## 3. Themes

```sh
bin/rails nibble:generate:theme tidewater
bin/rails nibble:generate:view customers/show --collection=customers
npm run lint           # ESLint over your themes and the screens you ejected
npm run format         # Prettier rewrites them in Nibble's style
npm run format:check   # or only reports the files it would change
```

## 4. Content

```sh
bin/rails nibble:content:export site/packages/default    # --collections= --taxonomies= --locales= --status=
bin/rails nibble:content:validate site/packages/default  # check a package, write nothing
bin/rails nibble:content:import site/packages/default    # --mode=create|update --dry-run --webhooks
bin/rails nibble:content:migrate                                         # pending site/schema/migrations/*.yml; --dry-run
bin/rails nibble:reindex                                          # every search index, including files
bin/rails nibble:cleanup:assets                                     # lists unused uploads; --confirm deletes, --older-than-days=
```

> [!WARNING]
> `nibble:cleanup:assets --confirm` deletes files for good. Read [Backups](backups.md#51-uploads-and-the-database-can-disagree)
> before running it after a restore.

## 5. People

```sh
bin/rails nibble:admin:create                                 # asks for a role, name, email and password
bin/kamal app exec -i 'bin/rails nibble:admin:create'         # the same, on the server
```

## 6. Installing, upgrading and deploying

```sh
curl -fsSL nibble.ink/install.sh | bash   # a new site
bin/rails nibble:install                  # --defaults, --force, --only=deploy
bin/rails nibble:eject <path>             # take one of Nibble's Control Plane screens on
bin/rails nibble:upgrade [version]        # on your own machine, never a server; --force
bin/rails nibble:prepare                  # migrations and checks — runs before every boot
bin/kamal setup                           # the first deploy
bin/kamal deploy                          # every deploy after
```

## 7. Development only

```sh
bin/rails nibble:dev:seed                 # realistic demo posts, authors and topics
bin/rails nibble:dev:setup                # connect Claude Code, Cursor and Codex to the developer tools
bin/rails nibble:dev:mcp                  # the developer tools over MCP, for an agent
bin/rails nibble:dev:tool render '{"path":"/"}'  # one developer tool, as JSON
RAILS_ENV=test bin/rails nibble:bench     # render and listing budgets; --posts=, --requests=
bin/ssr-smoke                             # every page through a fresh server-rendering build
```

The developer tools are described in [Building with an agent](../extending/building-with-agents.md).

## 8. The nibble command

`nibble` runs every task above without `bin/rails nibble:` — `nibble check`, `nibble upgrade` — and works on the
content of sites you sign in to. See [The nibble command](cli.md).

The **playground**, at `/cp/nibble/playground` in development, renders every blueprint — plus one using every
fieldtype — backed by records in memory. It is the fastest way to see what a field looks like without making content.

## 8. Nibble's own releases

```sh
bin/nibble-release 0.16.0
```

Only for working on Nibble itself. See [Releases](../contributing/releases.md).

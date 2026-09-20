---
title: Upgrading
description: Taking a release, what it asks you, and how to undo it.
order: 5
---

# Upgrading

Releases are tags. **Upgrade on your own machine, check the result, then deploy it** — never in place on a server,
which the command refuses to do. Commit everything first: a clean tree is what lets you undo anything it does.

```sh
bin/nibble-upgrade          # the newest release
bin/nibble-upgrade 0.4.0    # a particular one
```

It snapshots the database and prints the command that puts it back, checks the release can upgrade from your
version and that your machine meets its Ruby and Node floors, merges, installs dependencies, and runs
`bin/rails nibble:upgrade` for the database and content migrations.

## What it asks you

Two kinds of file a merge cannot decide for you:

- **Files you own that Nibble generates** — `config/nibble.yml`, `.env`, the deploy files. If the template has
  moved on, it re-renders yours from the answers your install recorded and offers it, with a diff. Your
  `load_defaults` is kept, so new behaviour still stays off.
- **Files you ejected.** For each one it shows what changed in Nibble's copy since you took yours, so you can
  decide what to carry across.

## Undoing it

The way back has a boundary, and the command names it as it crosses:

- **Before the migrations run**, `git merge --abort` undoes everything.
- **After them**, restore the snapshot it printed. A release whose migrations cannot be undone says so in
  `CHANGELOG.md`.

## Conflicts

An upgrade should only stop where you changed something of Nibble's. `bin/rails nibble:check` tells you which
files those are before you start.

`package-lock.json` is the one file both of you write — your own theme or packages have to go in it. The upgrade
rebuilds it; if git stops there, take either side and run `npm install`.

## Hearing about releases

**Updates** in the control panel lists releases newer than yours, what each changed, and the command that takes
it. It is checked once a day in the background; reading that file is all that happens, and a switch on that screen
stops even it.

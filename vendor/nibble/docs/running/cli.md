---
id: running-cli
title: The nibble command
description: One command to start a site, run its tasks, and work on the content of any site you sign in to — from a
  terminal, a script or an AI agent.
order: 9
---

# The nibble command

`nibble` is a single program for your computer. Tidewater's developer uses it three ways: to start a new site, to
run the site's tasks without typing `bin/rails`, and to fix a post on the live site from a terminal.

After reading this guide, you will know:

- How to start a site with it.
- How it runs a site's tasks.
- How to sign in to one or more sites, and work on their content.
- How to connect AI apps and install the site's guide for them.

## 1. Starting a site

```sh
nibble new tidewater
```

It checks this computer has what Nibble needs, downloads the latest release, checks it against its published
checksum, and runs the installer. `--version 0.19.0` picks a release; anything after `--` goes to the installer.

## 2. A site's tasks

Inside a site's folder, a word that isn't one of the command's own runs a task: `nibble check` is
`bin/rails nibble:check`, and `nibble schema show collections/posts` is `bin/rails nibble:schema:show collections/posts`.
The command's own words are `new`, `auth`, `remote`, `mcp`, `skill`, `doctor`, `help` and `completion`; no task
uses them.

## 3. Signing in

```sh
nibble auth login tidewater.example
```

Your browser opens the site. Sign in there — the command never sees your password — and choose what it may do, as
for [any app](../editing/ai-apps.md). The sign-in is kept in your system's keychain.

| Command | Does |
|---|---|
| `nibble auth list` | every site and account you're signed in to; `*` marks the one commands use |
| `nibble auth switch tidewater.example:you@tidewater.example` | use that site and account |
| `nibble auth status` | who you are on the current site, and what you may do there |
| `nibble auth logout` | sign out, and disconnect the command on the site |

You can be signed in to many sites, and to one site as several people; `--site` on any command picks one.

- **A server without a browser:** `nibble auth login tidewater.example --device` shows a code to type into the
  Control Plane, if the site allows it.
- **No keychain** (a bare Linux server): `--insecure-storage` keeps the sign-in in a file only you can read, and
  `nibble doctor` reminds you.
- **CI:** create a token for a script under **Connected apps**, and set `NIBBLE_SITE` and `NIBBLE_TOKEN`.

**A folder that always means one site.** Put `site = "tidewater.example"` in a `.nibble.toml`, and run
`nibble auth allow` there once. A `.nibble.toml` you haven't allowed is refused, so a repository you clone can't point
your commands at a site you didn't choose.

## 4. Working on content

```sh
nibble remote                                        # what you can do on this site
nibble remote list-entries --collection posts
nibble remote get-entry --id 12
nibble remote update-entry --id 12 --lock-version 3 --data '{"title":"Invoices, faster"}' --dry-run
nibble remote update-entry --id 12 --lock-version 3 --data @change.json
```

The operations come from the site, so they always match what it offers and what you may do. `--help` after one lists
its arguments. Objects take JSON, `@file.json`, or `-` for standard input. `--dry-run` shows the change without
making it. A change to an entry is a draft until it's published; every change says which site and account made it.

On a terminal, lists print as tables. Piped, or with `--json`, every command prints `{"ok": true, "data": …}` or
`{"ok": false, "error": {"code", "message", "hint"}}`. `--pick entries.0.title` prints one value.

## 5. AI apps

```sh
nibble mcp install --client claude-code     # or codex, cursor; claude and chatgpt show where to paste the address
nibble skill install --client claude        # the site's guide, as a skill Claude or Codex loads when it's relevant
nibble skill sync                           # refresh installed guides after the site's schema or notes change
```

The guide is written from the site's schema and its own notes in `site/agents/*.md` — put your editorial style
there — so each site's is different.

## 6. When something is wrong

```sh
nibble doctor
```

checks the configuration, the keychain, the site folder, your sign-in and what the site lets you do, and says how to
fix what fails.

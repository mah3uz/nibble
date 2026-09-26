<p align="center">
  <img src="nibble.svg" alt="Nibble" width="30%">
</p>

# Nibble

A content management system you run as your own application. Install it, and it becomes your site — your theme,
your content, your server.

<p align="center">
  <img src="nibble-banner.svg" alt="Nibble" width="100%">
</p>

Rails 8 serves both the public site and the Control Plane through Inertia and Vue 3, rendered on the server.
Collections, taxonomies, globals, navigation and forms are declared in YAML — Nibble's, then your theme's, then
yours — and the content itself lives in SQLite. Uploads go to S3. Deployment is Kamal onto one machine.

Upgrades arrive as releases, and each one replaces `vendor/nibble` whole.

## Alpha

> [!WARNING]
> **Nibble is in `alpha` and under heavy development.** Expect breaking changes often: settings, schema keys, commands
> and the theme API can change from one release to the next. Read the [changelog](CHANGELOG.md) before every
> upgrade.

## Install

```sh
curl -fsSL nibble.ink/install.sh | bash
```

It checks for what it needs — Ruby, Node, npm, SQLite, libvips, ffmpeg — names anything missing, asks for your site's
name (its folder is named after it), then downloads the latest release, checks it against its published checksum,
unpacks it into the site's `vendor/nibble` and asks a handful of questions. Everything outside `vendor/nibble` is
written once, and is yours from then on. `… | bash -s my-site` names the folder without asking.

```sh
bin/dev                  # the site on :3100, the Control Plane at /cp
bin/rails nibble:check   # the schema, theme, roles and settings are sound
bin/rails nibble:version # the release this site runs
```

To work on Nibble itself, clone this repository and run `bin/setup`; `bin/ci` runs every check Nibble runs on itself.

## Documentation

The documentation is written in Markdown and published at [nibble.ink][site].

| For | Read |
|---|---|
| a first site, step by step | [Start here][start] |
| running a site | [Running a site][users] |
| writing and publishing | [Editing content][editors] |
| collections, blueprints and fields | [Modelling content][modelling] |
| building the site's looks | [Building a theme][themes] |
| extending Nibble | [Extending Nibble][extensions] |
| working on Nibble itself | [Contributing to Nibble][developers] |

## What belongs to you

**Everything under `vendor/nibble/` is Nibble's. Everything else is yours** — including `app/`, so your own models,
controllers and jobs sit where a Rails application puts them.

To take one of Nibble's files on, `bin/rails nibble:eject <path>` copies it somewhere yours is found first and
records that you now maintain it. `bin/rails nibble:check` then tells you when the original moves on, and
reports anything of Nibble's you changed *without* ejecting — the files an upgrade would otherwise stop on.

## Upgrading

```sh
bin/rails nibble:upgrade
```

On your own machine, never on a server. It downloads the release and checks it against its published checksum,
refuses if Nibble's own files were changed in place, checks the release's requirements, snapshots the database,
swaps in the new `vendor/nibble` (keeping the old one in `tmp/`) and migrates — asking about the files it cannot
decide for you. See [Upgrading][upgrading].

## Licence

MIT — see `LICENSE`. Use it, change it, sell it, rebrand the Control Plane; keep the copyright notice with
copies. It comes with no warranty and no support promise.

[site]: https://nibble.ink
[start]: https://nibble.ink/docs/getting-started
[users]: https://nibble.ink/docs/running
[editors]: https://nibble.ink/docs/editing
[modelling]: https://nibble.ink/docs/modelling
[themes]: https://nibble.ink/docs/theming
[extensions]: https://nibble.ink/docs/extending
[developers]: https://nibble.ink/docs/contributing
[upgrading]: https://nibble.ink/docs/running/upgrading

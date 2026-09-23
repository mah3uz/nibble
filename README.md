<p align="center">
  <img src="nibble-banner.svg" alt="Nibble" width="100%">
</p>

# Nibble

A content management system you run as your own application. Clone it, install it, and it becomes your site —
your theme, your content, your server.

Rails 8 serves both the public site and the control panel through Inertia and Vue 3, rendered on the server.
Collections, taxonomies, globals, navigation and forms are declared in YAML — Nibble's, then your theme's, then
yours — and the content itself lives in SQLite. Uploads go to S3. Deployment is Kamal onto one machine.

Upgrades arrive as releases you merge.

## Install

```sh
./install.sh my-site
```

It checks for what it needs — git, Ruby, Node, npm, SQLite, libvips, ffmpeg — names anything missing, then
clones, installs dependencies and asks a handful of questions.

```sh
bin/dev                  # the site on :3100, the control panel at /admin
bin/rails nibble:check   # the schema, theme, roles and settings are sound
bin/ci                   # every check Nibble runs on itself
```

## Documentation

The documentation is its own site, written in Markdown and published from [nibble_site][site].

| For | Read |
|---|---|
| running a site | [Running a site][users] |
| writing and publishing | [Editing content][editors] |
| building the site's looks | [Building a theme][themes] |
| extending Nibble | [Extending Nibble][extensions] |
| working on Nibble itself | [Developing Nibble][developers] |

## What belongs to you

**Everything under `vendor/nibble/` is Nibble's. Everything else is yours** — including `app/`, so your own models,
controllers and jobs sit where a Rails application puts them.

To take one of Nibble's files on, `bin/rails nibble:eject <path>` copies it somewhere yours is found first and
records that you now maintain it. `bin/rails nibble:check` then tells you when the original moves on, and
reports anything of Nibble's you changed *without* ejecting — the files an upgrade would otherwise stop on.

## Upgrading

```sh
bin/nibble-upgrade
```

On your own machine, never on a server. It snapshots the database, checks the release's requirements, merges,
and migrates — asking about the files it cannot decide for you. See [Upgrading][upgrading].

## Licence

MIT — see `LICENSE`. Use it, change it, sell it, rebrand the control panel; keep the copyright notice with
copies. It comes with no warranty and no support promise.

[site]: https://nibble.ink
[users]: https://nibble.ink/docs/running
[editors]: https://nibble.ink/docs/editing
[themes]: https://nibble.ink/docs/theming
[extensions]: https://nibble.ink/docs/extending
[developers]: https://nibble.ink/docs/contributing
[upgrading]: https://nibble.ink/docs/running/upgrading

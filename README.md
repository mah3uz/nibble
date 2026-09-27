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

It installs [the `nibble` command](https://github.com/mah3uz/nibble-cli) if you haven't got it, then runs
`nibble new`: it checks for what it needs — Ruby, Node, npm, SQLite, libvips, ffmpeg — and says how to get anything
missing, asks for your site's name (its folder is named after it), downloads the latest release, checks it against
its published checksum and that your Ruby and Node are new enough, unpacks it into the site's `vendor/nibble` and asks
a handful of questions. Everything outside `vendor/nibble` is
written once, and is yours from then on. `… | bash -s my-site` names the folder without asking.

```sh
bin/dev                  # the site on :3100, the Control Plane at /cp
bin/rails nibble:check   # the schema, theme, roles and settings are sound
bin/rails nibble:version # the release this site runs
```

To work on Nibble itself, clone this repository and run `bin/setup`; `bin/ci` runs every check Nibble runs on itself.
Cutting a release also runs the `nibble` CLI's checks against it, so clone
[mah3uz/nibble-cli](https://github.com/mah3uz/nibble-cli) into `cli/` first.
The documentation is in `vendor/nibble/docs`, and ships with every release.

## AI apps and agents

Once an administrator turns on Agent access, people can connect Claude, ChatGPT, Codex or Cursor to the site at
`/mcp`, and the [`nibble` command-line tool](https://github.com/mah3uz/nibble-cli) to the management API at
`/api/v1/operations`. An app works as the person who
connected it and can never do more than they can; publishing and changes that go live at once wait for that person's
approval. In development, `bin/rails nibble:dev:mcp` gives an agent building the site tools to render pages, check,
test and read logs. See [Agent access][agents] and [Building with an agent][dev-agents].

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
[agents]: https://nibble.ink/docs/running/agent-access
[dev-agents]: https://nibble.ink/docs/extending/building-with-agents
[start]: https://nibble.ink/docs/getting-started
[users]: https://nibble.ink/docs/running
[editors]: https://nibble.ink/docs/editing
[modelling]: https://nibble.ink/docs/modelling
[themes]: https://nibble.ink/docs/theming
[extensions]: https://nibble.ink/docs/extending
[developers]: https://nibble.ink/docs/contributing
[upgrading]: https://nibble.ink/docs/running/upgrading

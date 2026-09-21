<p align="center">
  <img src="nibble-banner.svg" alt="Nibble" width="100%">
</p>

# Nibble

A schema-driven CMS. Rails 8 serves the public site and the control panel through Inertia + Vue 3 with
server-side rendering. Collections, taxonomies, globals, navigation, assets and forms are defined in YAML
(Nibble's own, then the theme's, then yours), and their content lives in SQLite.

You run Nibble as your whole application: clone it, install it, and make the site yours through your own theme,
your own schema and your own settings. Upgrades arrive as releases you merge.

## Install

```sh
./install.sh my-site
```

It checks for what it needs — git, Ruby, Node, npm, SQLite, libvips, ffmpeg — names anything missing, then
clones, installs dependencies and asks the handful of questions it needs. See
[Installing](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/users/installing.md).

```sh
bin/dev                  # the site on :3100, the control panel at /admin
bin/ci                   # every check Nibble runs on itself
bin/rails nibble:check   # the schema, theme, roles and settings are sound
```

## Documentation

| For | Read |
|---|---|
| running a site | [Running a site](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/users/index.md) |
| writing and publishing | [Editing content](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/editors/index.md) |
| building the site's looks | [Building a theme](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/themes/index.md) |
| extending Nibble | [Extending Nibble](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/extensions/index.md) |
| working on Nibble itself | [Developing Nibble](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/developers/index.md) |

## What belongs to you

**Everything under `lib/nibble/` is Nibble's. Everything else is yours** — including `app/`, so your own models,
controllers and jobs sit where a Rails application puts them.

To change one of Nibble's files, `bin/rails nibble:eject <path>` copies it where yours is found first and records
that you now maintain it. `bin/rails nibble:check` then tells you when the original moves on, and reports
anything of Nibble's you changed without ejecting — the files an upgrade will stop on.

## Upgrading

```sh
bin/nibble-upgrade
```

On your own machine, never on a server. It snapshots the database, gates on the release's requirements, merges,
and migrates — asking about the files it cannot decide for you. See [Upgrading](https://gitea.tlbn.app/mahfuz/nibble_site/src/branch/main/content/docs/users/upgrading.md).

## Licence

MIT — see `LICENSE`. Use it, change it, sell it, rebrand the control panel; keep the copyright notice with copies.
It comes with no warranty and no support promise.

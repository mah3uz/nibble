---
id: contributing-releases
title: Releases
description: Cutting a Nibble release, writing the changelog a site reads, and the versions code checks.
order: 4
---

# Releases

A release is an annotated tag on `main` and an archive published beside it on GitHub. There is no stable branch, no
backports and no release candidates: the install and upgrade test is the gate, and `bin/rails nibble:upgrade` finds
the newest release itself.

After reading this guide, you will know:

- How to cut a release, and what the script refuses.
- How the changelog becomes the notes every Control Plane shows.
- Which version numbers code checks, and which are for people.

## 1. Cutting one

```sh
bin/nibble-release 0.15.0
```

It refuses a malformed or backwards version, a dirty tree, a checkout without `cli/`, and an empty `Unreleased`
section. Then it bumps `Nibble::VERSION`, dates the changelog section, runs `bin/ci`, then the CLI's own checks
(`cli/script/ci`) against this release, and only then commits and tags. If either fails, nothing is committed or
tagged.

The `nibble` CLI is released on its own, from `mah3uz/nibble-cli`, and sites run whichever version their people
installed. Its checks include a contract test that signs in to this checkout and works on content through the
management API, so a release that would break the CLI people already have is caught before it is tagged. Clone it
into `cli/` once:

```sh
git clone git@github.com:mah3uz/nibble-cli.git cli
```

It then offers to push `main` and the tag. `--push` pushes without asking; answering no prints the command to push
later:

```sh
git push https://github.com/mah3uz/nibble.git main --follow-tags
```

Once the tag is pushed it packs the release — `vendor/nibble` as a site receives it, with its `VERSION`, `MANIFEST`
and lock files — and publishes the archive and its `SHA256SUMS` as a GitHub release, using `gh`. If that step fails,
pack and publish the tagged release again on its own:

```sh
bin/nibble-release 0.15.0 --pack
```

### 1.1 The feed

Last, it writes the release feed into nibble.ink's `site/content/changelogs/`, runs `bin/release-pages` to write a
page per release, and offers to commit them in `site/`. A checkout without nibble.ink's `site/` skips this step.
Control panels see the release once nibble.ink is deployed.

## 2. The changelog is the release

`CHANGELOG.md` records what changed **for a site running Nibble**, under `What's new`, `Changed`, `What's fixed` and
`Security`. Anything that needs action carries an **Upgrade** note, and a release whose migrations cannot be undone
says so, because the snapshot is then the only way back.

> [!IMPORTANT]
> Write entries for someone running a site, not for someone reading the diff: what they will see, and what, if
> anything, they must do. The same text appears on every Control Plane's **Updates** screen.

### 2.1 A headline

A release that is a milestone opens with a quote: its headline in bold, then a sentence saying what it means for a
site.

```markdown
## 0.16.0 — 2026-09-24 04:39 +0600

> **Installed and upgraded as one folder.** Nibble lives in `vendor/nibble` and loads as a Rails engine; an upgrade
> replaces that folder and leaves the rest to the site.

### What's new
```

The feed carries them as `headline` and `summary`. The release's page takes the summary as its description, and
nibble.ink's roadmap puts every release with a headline on the road behind "You are here". A stop planned for a
version moves behind the pin by itself once that version is released. Most releases need no headline.

### 2.2 The feed

The feed is `site/content/changelogs/releases.json` in nibble.ink's `site/`, generated from the whole changelog, every
release included. It is rebuilt each time, so the changelog is the only record — editing an entry
after its release still reaches every site. It is served at `/api/v1/changelogs`, which `Nibble::CHANGELOGS_FEED`
names.

## 3. Versions

`Nibble::VERSION` orders releases for people. The contracts — `SCHEMA_FORMAT`, `THEME_API_VERSION`,
`CONTENT_FORMAT_VERSION` and `MANAGEMENT_API_VERSION` — are what code checks. `Release::MINIMUM_UPGRADE_FROM` says how far back an upgrade can start,
and the Ruby and Node floors come from `.ruby-version` and `package.json`, checked before an upgrade changes anything.

Nibble is `0.x` until someone outside installs it; while it is, anything can change between releases.

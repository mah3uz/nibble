---
title: Releases
description: Cutting one, and what a site sees.
order: 6
---

# Releases

Releases are annotated tags on `main`. There is no stable branch, no backports and no release candidates: the
upgrade test is the gate, and `bin/nibble-upgrade` resolves the newest tag itself.

```sh
bin/nibble-release 0.6.0
```

It refuses a malformed or backwards version, a dirty tree, and an empty Unreleased section. Then it bumps
`Nibble::VERSION`, dates the changelog section, regenerates `docs/releases.json`, runs `bin/ci`, and only then
commits and tags. Push with `git push origin main --follow-tags`.

## The changelog is the release

`CHANGELOG.md` records what changed **for a site running Nibble**, under `What's new`, `Changed`, `What's fixed`
and `Security`. Anything needing action carries an `**Upgrade:**` line. A release whose migrations cannot be
undone says so, because the snapshot is then the only way back.

`docs/releases.json` is generated from that entry, capped at the most recent 25 releases, and is what a site's
control panel reads to say a release exists. The two cannot drift, because one is written from the other.

## Versions

`Nibble::VERSION` orders releases for people. The contracts — `SCHEMA_FORMAT`, `THEME_API_VERSION`,
`CONTENT_FORMAT_VERSION` — are what code checks. `Release::MINIMUM_UPGRADE_FROM` states how far back an upgrade
can start, and the floors for Ruby and Node are read from `.ruby-version` and `package.json`, checked **before**
a merge.

`0.x` until someone outside installs it: while it is `0.x`, anything can change between releases.

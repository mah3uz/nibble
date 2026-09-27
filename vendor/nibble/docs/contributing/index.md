---
id: contributing
title: Contributing to Nibble
description: Working on Nibble itself — getting set up, finding your way around, and sending a change back that is
  easy to take.
order: 7
---

# Contributing to Nibble

This section is for working on Nibble itself. If you are building a site *with* Nibble, you want
[Building a theme](../theming/index.md) — you should almost never need to change Nibble to build a site, and if you
do, that is worth an issue.

After reading this guide, you will know:

- How to set up Nibble for development.
- Why sending a change back is cheaper than keeping it.
- How to send one, and what makes it easy to take.

## 1. Getting set up

```sh
git clone https://github.com/mah3uz/nibble.git
cd nibble
bin/setup
bin/dev
```

`bin/setup` installs dependencies, prepares the database, imports the starter content into an empty one and prints
the command that creates your first user; `bin/dev` starts Rails, Vite and server-side rendering together. The site
is at `http://localhost:3100`, and `bin/rails nibble:dev:seed` fills it with demo posts.

Nibble itself is `vendor/nibble/`, as it is in every site; the rest of the checkout is nibble.ink, the site that
publishes Nibble. Its `site/` is kept elsewhere, so a fresh clone runs on the starter theme.

Before you push anything:

```sh
bin/ci
```

It is the same suite a release refuses to go out without. See [Tests and checks](testing.md).

## 2. Why send a change back

Say you find a bug in the dashboard while building Tidewater, and fix it in place. It works — until the next upgrade,
which refuses to replace the file, and again the upgrade after. **A patch you keep is in the way of every
upgrade**, and an ejected file stops receiving fixes. Anything you fixed once, you will otherwise fix again.

1. `bin/rails nibble:check` on your site — see exactly which of Nibble's files you changed.
2. Clone Nibble and make the change there, with a test that fails without it.
3. `bin/ci`.
4. Send it to the repository named in `Nibble::REPOSITORY`, saying what it fixes for a site rather than how.
5. Once it is released, take the release and drop your copy.

## 3. What makes a change easy to take

- **A test that encodes why**, not just what. If the rule changes later, the test should fail and say so.
- **The smallest change that solves it.** Touch what you must; leave adjacent code alone.
- **Comments only where the code cannot show it** — a constraint, a workaround, the reason behind something
  surprising. Never a restatement of the line below.
- **Say what it does, not where it came from.** No ticket or plan numbers in the code or the commit message.
- **A changelog entry** under `Unreleased`, written for someone running a site — see [Releases](releases.md).

> [!IMPORTANT]
> Read [Invariants](invariants.md) before a change that touches sanitising, redirects, database queries, imports or
> the line between Nibble's files and a site's. They are the rules the codebase does not bend.

## 4. The guides in this section

| Guide | Covers |
|---|---|
| [Architecture](architecture.md) | where code lives, how a request becomes a page, the modules |
| [Invariants](invariants.md) | the rules the codebase holds to, and the tests that enforce them |
| [Tests and checks](testing.md) | `bin/ci`, the test suites, end-to-end tests and the playground |
| [Releases](releases.md) | cutting a release, and what a site sees |

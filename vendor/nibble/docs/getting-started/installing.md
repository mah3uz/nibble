---
id: getting-started-installing
title: Installing Nibble
description: What your machine needs, every question the installer asks, the files it writes, and what to do when
  something goes wrong.
order: 2
---

# Installing Nibble

Nibble is installed from a release. The installer downloads it into your site's `vendor/nibble`, writes the rest of
the application around it, and every later release replaces that one folder and nothing else.

After reading this guide, you will know:

- What your machine needs, and how to get it.
- What the installer does, question by question.
- Which files the installer writes, and which of them belong in git.
- How to check the install worked, and what to do when it did not.

## 1. What your machine needs

| Tool | Why |
|---|---|
| Ruby 4 | the application |
| Node 24 or newer, and npm | the asset build, and server-side rendering |
| SQLite | the database — it also holds the cache and the job queue |
| libvips | resizing images |
| ffmpeg | thumbnails for video |

Most systems' own Ruby and Node are older than that, so install those two with [mise](https://mise.jdx.dev), which
also reads the Ruby version a site pins in its `.ruby-version`:

```sh
mise use --global ruby@latest node@lts
```

git is not needed to install or upgrade, though a site's own history belongs in it.

> [!NOTE]
> There is no database server, no Redis and no search service to set up. SQLite holds all of it, which is why a
> Nibble site runs on one small machine.

If something is missing, the installer stops **before doing anything** and names everything that is missing at
once: mise for Ruby and Node, and your system's own packages for the rest — Homebrew on macOS, apt on Debian and
Ubuntu, pacman on Arch Linux:

```
error this computer is missing:
    vips — image resizing (package: libvips / libvips-tools)
  The rest, on Arch Linux: sudo pacman -S --needed sqlite libvips ffmpeg
```

It checks the versions too, once it has the release: a Ruby or Node older than the release needs is named, with the
mise command that gets the right one, before anything is installed.

## 2. Running the installer

Tidewater's site was created with:

```sh
curl -fsSL nibble.ink/install.sh | bash
```

It works from any shell, fish included, on Linux and macOS. It installs [the `nibble` command](../running/cli.md)
into `~/.local/bin` if this computer hasn't got it, checked against the checksum published with it, and hands over
to `nibble new`, which:

1. Checks the tools above.
2. Asks for the site's name and makes its folder from it, spaces becoming dashes: `Tide water` becomes
   `Tide-water/`. If the folder already exists it asks again. `… | bash -s tidewater` names it without asking.
3. Downloads the latest release, checks it against its published checksum, checks your Ruby and Node against what it
   needs, and unpacks it into `tidewater/vendor/nibble`. Set `NIBBLE_VERSION=0.16.0` to take a particular release
   instead.
4. Writes the files that need no answers, and runs `bundle install` and `npm install`, starting from the versions that
   release was tested with — the slow part.
5. Hands over to `bin/rails nibble:install`, which asks the questions below, then generates the types your theme
   reads.

With the `nibble` command already installed, `nibble new tidewater` does the same; options for `nibble:install` go
after `--`, as in `nibble new tidewater -- --defaults`.

## 3. The questions

Each question shows a default in brackets; pressing Enter takes it.

### 3.1 The site

**Application name.** Names the containers, image and volume when you deploy. Lowercase, no spaces: `tidewater`,
not `Tidewater Site`. It defaults to the folder's name, lowercased.

**Public site URL.** Where the site will live: `https://tidewater.example`. Canonical links, sitemaps, feeds and
links in emails are all built from it.

> [!IMPORTANT]
> In production the URL must be `https`. A site that boots with an `http` URL refuses to start rather than send
> search engines to the wrong address.

**Theme handle.** Take `crumbs`, the theme Nibble ships, and [generate your own](../theming/index.md) once the site
is running.

### 3.2 Deploying

**Whether you deploy with Kamal.** Say yes and it asks for four more things, and writes the deploy files:

| Question | Tidewater's answer |
|---|---|
| Production domain | `tidewater.example` |
| Production server address | `203.0.113.10` |
| Container registry username | `tidewater` |
| SSH user on the servers | `root` |

Say no and nothing is lost — add them whenever you are ready:

```sh
bin/rails nibble:install --only=deploy
```

### 3.3 The administrator

A name, an email address and a password. **This one is not optional**: a site with no administrator has no way
in. The password needs at least 12 characters, with a lowercase letter, an uppercase letter, a number and a symbol —
the same rule applies wherever a password is set later.

### 3.4 Example content

Nibble offers a few example pages, posts and terms so a fresh site is not an empty screen. They are Nibble's own
starter content, not your theme's. Take them while you learn; decline them for a site going straight into use.

## 4. What it writes

| File | What it is | Commit it? |
|---|---|---|
| `vendor/nibble/` | Nibble itself — replaced whole by each upgrade, never edited | yes |
| `Gemfile`, `package.json`, `config/`, `bin/`, `app/`, `test/`, `site/` | the application around Nibble, written from its templates | yes |
| `config/nibble.yml` | how your site behaves — see [Configuration](../running/configuration.md) — and, below its last line, the record of which release this site is on and your answers | yes |
| `.env` | secrets and addresses for this machine | **no** — already ignored |
| `config/master.key` | the key that decrypts your credentials | **no** — keep a copy somewhere safe |
| `config/credentials.yml.enc` | encrypted secrets | yes |
| `CLAUDE.md` | notes for an AI agent working in your repository | yes |
| `Dockerfile`, `.dockerignore`, `bin/docker-entrypoint` | how the image is built and started, if you deploy with Kamal | yes |
| `config/deploy.yml`, `.kamal/secrets`, `.kamal/hooks/` | Kamal's own files, with Nibble's settings merged into `deploy.yml` | yes |

Everything outside `vendor/nibble` is yours from the moment it is written. Nibble generates it once and never writes
it again, so you can edit it freely without an upgrade fighting you. An upgrade that changes one of its templates
offers the new version, and you choose.

> [!CAUTION]
> **Keep `config/master.key` somewhere safe**, such as a password manager. Without it the encrypted credentials
> cannot be read, and a production site will not boot.

## 5. Checking it worked

```sh
cd tidewater
bin/rails nibble:check
```

This reads the schema, the theme, the roles and the settings, and reports anything wrong in plain language. A
clean site prints one line:

```
nibble:check passed (20 schema files)
```

Then start it:

```sh
bin/dev
```

- The site: `http://localhost:3100`
- The Control Plane: `http://localhost:3100/cp`

## 6. If something goes wrong

**The installer says a tool is missing.** Install everything it lists and run it again. It refuses a directory
that already exists, so delete the half-made one or choose another name.

**The installer stopped part way.** Run `bin/rails nibble:install` inside the folder — it is safe to run again, and
never overwrites a file without `--force`. Then `npm install` and `bin/rails nibble:build`.

**The download doesn't match its checksum.** Nothing was installed. Run the installer again; if it keeps happening,
report it, because what you downloaded is not what was published.

**`bin/dev` starts but the site is blank or unstyled.** The first asset build is still running; give it a few
seconds.

**You cannot sign in.** Passwords are case-sensitive. Make another administrator with
`bin/rails nibble:admin:create`.

> [!TIP]
> When something is wrong and you do not know what, run `bin/rails nibble:check` first. It explains most
> misconfigurations, and `bin/rails nibble:check --support` prints a summary of your install to paste into an issue.

## 7. What's next

- [Getting Started with Nibble](tutorial.md) — build the Tidewater site on the install you just made.
- [Configuration](../running/configuration.md) — everything `config/nibble.yml` can say.
- [Deploying](../running/deploying.md) — put it on a server.

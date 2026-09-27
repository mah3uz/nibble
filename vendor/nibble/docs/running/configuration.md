---
id: running-configuration
title: Configuration
description: Where each kind of setting lives — config/nibble.yml, the environment and credentials, and the control
  panel — and every key each one takes.
order: 1
---

# Configuration

Nibble reads settings from four places, each for a different kind of thing. Getting that split right is most of
what keeps a site easy to run.

After reading this guide, you will know:

- Which settings go in a file, which in the environment, and which in the Control Plane.
- Which Rails settings Nibble needs, and where they are written.
- Every key `config/nibble.yml` takes.
- How image presets work.
- What is checked before a site serves.

## 1. Four places

| Where | For | In git? |
|---|---|---|
| `config/nibble.yml` | how the site behaves: theme, URL, locales, upload rules | **yes** |
| Rails' own `config/` | how the application runs: time zone, mail delivery, storage, jobs, security headers | **yes** |
| the environment and credentials | secrets, and addresses that differ per machine | credentials yes, `.env` no |
| the Control Plane | what a person changes without a deploy | it lives in the database |

The rule of thumb: **if changing it should be reviewed, it belongs in a file. If it is a secret, it belongs in
credentials or the environment. If a colleague should be able to change it on a Tuesday afternoon, it belongs in
the Control Plane.**

## 2. config/nibble.yml

Written once by the installer and yours from then on. It holds **only what you have set** — everything else has a
default in code, so the file stays short. Tidewater's:

```yaml
default: &default
  theme: tidewater
  url: https://tidewater.example
  locales:
    - code: en
      default: true
      url_prefix: ""
  outbound:
    allowed_hosts: [api.crm.example]
    secrets: [crm_token]

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

`default: &default` and `<<: *default` are ordinary YAML for "every environment starts from these". Give an
environment its own values below the `<<:` line when it genuinely differs.

## 3. Rails' own settings

A site is a Rails application, and every Rails setting lives where Rails keeps it. The installer writes the few that
Nibble needs into those files, each under a `# Nibble:` comment that says why. They are yours to change like any
other line:

| File | What Nibble needs from it |
|---|---|
| `config/application.rb` | `config.time_zone`: the clock editors write in and scheduling runs on, such as `"Europe/London"`; UTC when unset |
| `config/environments/production.rb` | storage (S3 once `AWS_BUCKET_NAME` is set), and mail over SMTP for resets, invitations and notifications |
| `config/recurring.yml` | Nibble's jobs: scheduled publishing, update checks, snapshots and purges |
| `config/initializers/inertia_rails.rb` | how pages render, on the server through the SSR process |
| `config/initializers/webauthn.rb` | passkeys, allowed from the site's own URL |
| `config/initializers/content_security_policy.rb` | a baseline policy: no plugins, no framing by other sites, forms post only here |
| `config/routes.rb` | `/up`, which Kamal's proxy asks before sending traffic |

Nibble's links in emails use `url` from `config/nibble.yml`, whatever host the application's own mailers are given.
In production, a missing job or a passkey setting that no longer allows the site's URL is named at boot and by
`bin/rails nibble:check`.

## 4. Every key

| Key | What it does |
|---|---|
| `theme` | the active theme's handle, a directory under `site/themes/`, or one Nibble ships such as `crumbs` |
| `url` | the public site URL; canonical links, sitemaps, feeds and mail are built from it |
| `locales` | the site's languages: `code`, `default`, `url_prefix`, and `search_tokenizer` (`porter` or `trigram`) |
| `reserved_paths` | paths content may never claim, on top of Nibble's own |
| `disable` | schema from Nibble or the theme to switch off, as `kind/handle` — `navigation/footer` |
| `trash.retention_days` | how long trashed content is kept; 30 by default |
| `session.idle_minutes` | how long a Control Plane session lasts without activity before it ends; 120 by default |
| `assets.max_upload_mb` | the largest file anyone may upload |
| `assets.additional_extensions` | file types beyond the ones allowed by default |
| `assets.presets` | named image sizes — see below |
| `outbound.allowed_hosts` | the only hosts Nibble may call, for form deliveries and webhooks |
| `outbound.secrets` | the secret names those calls may use |
| `outbound.config` | plain values those calls may use, as `{config.name}` |

> [!NOTE]
> `reserved_paths` only adds. Nibble always reserves `/cp`, `/api`, `/forms`, `/media`, `/assets`, `/nibble-assets`, `/up`,
> `/sitemap.xml`, `/robots.txt` and `/.well-known`, because a site whose Control Plane was shadowed by a page could
> not be fixed from inside.

## 5. Image presets

A preset is a named size a theme asks for, so the size lives in one place rather than in every template. Four exist
out of the box:

| Preset | Size | Used for |
|---|---|---|
| `card` | 960 × 640, cropped | listings |
| `hero` | 1920 × 1080, cropped | wide banners |
| `content` | fits in 1440 × 1440 | images in the body; also the widths for images [written beside files](../modelling/content-as-files.md) |
| `og` | 1200 × 630, cropped | share images |

Add your own, or change one, in `config/nibble.yml`:

```yaml
assets:
  presets:
    logo:
      w: 400
      h: 200
      fit: contain
    card:
      w: 800
      h: 800
      fit: crop
      srcset: [400, 800]
```

`fit: crop` fills the size exactly, keeping the focal point in frame; `fit: contain` fits inside it. `srcset` lists
the smaller widths a browser may choose instead. An `assets` field names its preset with `preset: logo`.

## 6. Environment and credentials

Secrets and per-machine addresses. In development they live in `.env`, which is never committed. In production they
are environment variables, set by the deploy, and the sensitive ones come from encrypted credentials.

| Variable | Purpose |
|---|---|
| `SITE_URL` | the public URL in production — must be `https` |
| `NIBBLE_THEME` | the active theme, when `config/nibble.yml` does not name one |
| `NIBBLE_BLOCK_INDEXING` | any value: disallow crawling, mark every page `noindex`, leave analytics off |
| `SMTP_ADDRESS`, `SMTP_PORT` | outgoing mail |
| `AWS_BUCKET_NAME`, `AWS_REGION` | store uploads in S3; without a bucket they are kept on the server's disk |
| `DB_SNAPSHOT_BUCKET`, `DB_SNAPSHOT_REGION` | where the nightly [backup](backups.md) goes |
| `INERTIA_SSR_PORT` | the port server-side rendering listens on, if 13714 clashes |
| `NIBBLE_SECRET_<NAME>` | a secret named in `outbound.secrets` |

| Credential | Purpose |
|---|---|
| `smtp.username`, `smtp.password` | the mail server's login |
| `aws.access_key_id`, `aws.secret_access_key` | uploads, and the nightly backup |
| `nibble.secrets.<name>` | a secret named in `outbound.secrets`, if not in the environment |

Edit credentials with:

```sh
bin/rails credentials:edit
```

The installer created `config/credentials.yml.enc`, which is committed, and `config/master.key`, which is not.

> [!CAUTION]
> Credentials are encrypted with `config/master.key`, which is **not** in git. Lose it and the credentials cannot be
> read, and production will not boot. Keep a copy somewhere safe, such as a password manager.

## 7. In the Control Plane

Some settings are nobody's business but the people using the site, and asking for a deploy to change them would be
absurd:

- **Globals → Integrations** — CAPTCHA keys, who mail comes from, analytics IDs, code for the page's head and body.
- **Globals → SEO** — the title template and the defaults for search results and share cards.
- **Updates** — whether Nibble checks for new releases.

They take effect as soon as they are saved.

## 8. Checked before the site serves

In production, a wrong setting **stops the boot and names every problem at once**, rather than failing later on
some unlucky request: a missing or non-`https` `SITE_URL`, credentials that will not decrypt, S3 storage without its
region or keys, a theme that is named but absent.

Two more are reported as warnings, and the site starts anyway: no mail login, so password resets and notifications
will not send; and no `DB_SNAPSHOT_BUCKET`, so backups stay on the server.

A console and a migration still start, on purpose — otherwise a broken setting could not be fixed on the machine it
is broken on.

```sh
bin/rails nibble:check
```

prints the same report whenever you ask. Run it before you deploy.

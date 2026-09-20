---
title: Settings
description: config/nibble.yml, environment variables, and what belongs in each.
order: 2
---

# Settings

Nibble reads settings from three places, and each is for a different kind of thing.

| Where | For | Committed? |
|---|---|---|
| `config/nibble.yml` | how the site behaves: theme, URL, locales, asset presets | yes, it is yours |
| Environment and credentials | secrets and per-server addresses | `.env` is not; credentials are |
| The control panel | what a person changes: the Integrations global, update checks | in the database |

## config/nibble.yml

Written at install, and yours from then on. It holds **only what you set** — everything else has a default in
code, so the file stays short and what is in it is what you maintain.

```yaml
default: &default
  load_defaults: "0.5.0"
  theme: almanac
  url: https://example.com
  locales:
    - code: en
      default: true
      url_prefix: ""

production:
  <<: *default
```

Keys you can set: `load_defaults`, `theme`, `url`, `locales`, `disable`, `reserved_paths`,
`trash.retention_days`, `assets.max_upload_mb`, `assets.additional_extensions`, `assets.presets`, and
`outbound.allowed_hosts`, `outbound.secrets` and `outbound.config`.

`load_defaults` is how new behaviour is turned on. A release never changes how your site behaves on its own:
behaviour introduced later stays off until you raise this number, having read what it changes.

`reserved_paths` is a floor, not a list you replace — a site adds to it, and cannot drop `/admin`.

## Environment

| Variable | Purpose |
|---|---|
| `SITE_URL` | Public site URL (development default `http://localhost:3100`) |
| `NIBBLE_THEME` | The active theme, when you would rather not set it in `config/nibble.yml` |
| `NIBBLE_BLOCK_INDEXING` | Any value disallows crawling, adds a `noindex` tag and leaves analytics off |
| `SMTP_ADDRESS`, `SMTP_PORT` | Outgoing mail; the username and password come from credentials |
| `AWS_REGION`, `AWS_BUCKET_NAME` | S3 storage for uploads |
| `DB_SNAPSHOT_BUCKET`, `DB_SNAPSHOT_REGION` | Where the nightly [backup](backups.md) is uploaded |
| `BASIC_AUTH_USER`, `BASIC_AUTH_PASSWORD` | Staging's HTTP Basic Auth |
| `NIBBLE_SECRET_<NAME>` | One per name in `outbound.secrets` |

## In the control panel

CAPTCHA keys, the address mail is sent from, and analytics IDs are **site settings**, edited in the Integrations
global rather than in a file. Whether Nibble checks for new releases is a switch on the Updates screen.

## Checked before it serves

In production and staging, a missing or wrong setting **stops the boot and names every problem at once** — no
`SITE_URL`, a URL that is not `https`, credentials that will not decrypt, S3 configured without a bucket, a theme
that is named but absent. A console or a migration still starts, so a broken setting can be fixed on the machine
it is broken on. `bin/rails nibble:check` reports the same list on demand.

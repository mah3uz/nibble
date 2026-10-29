---
id: modelling-form-spam-and-privacy
title: Form spam and privacy
description: Keep bots out of a form, close it on a schedule, and decide how long submissions are kept, encrypted and
  erased.
order: 7
---

# Form spam and privacy

A public form attracts bots, and what people type into it is personal data. This guide covers keeping the first out,
limiting who can submit and when, and looking after the second. To declare the form itself, see [Forms](forms.md).

After reading this guide, you will know:

- How the honeypot, rate limit and spam checks work, and how to turn on a CAPTCHA.
- How long submissions and spam are kept, and how to change it.
- How to find, export or erase everything held about one person.
- How to encrypt a field.
- How to open and close a form on dates, cap it, and accept a value once.

## 1. Spam

Every form gets two protections without asking:

- **A honeypot** — a hidden field people never fill in and bots usually do. Rename it with `spam.honeypot`, or turn
  it off with `honeypot: false`.
- **Rate limiting** — five accepted submissions a minute from one address by default. A post that fails validation
  doesn't use up the visitor's attempts, so someone correcting a long form isn't locked out; an address that sends ten
  times the limit of refused posts in the window is cut off too. A visitor over the limit is told how long to wait
  ("Try again in 4 minutes.").

A theme renders the honeypot as a visually hidden text input with `tabindex="-1"`, `autocomplete="off"` and
`aria-hidden="true"`, so keyboards, screen readers and autofill pass it by. Keep its name meaningless: browsers and
password managers fill in fields with names like `website` or `email`, and `bin/rails nibble:check` warns when the
honeypot has one.

Two more checks stay off until a form turns them on:

```yaml
spam:
  min_seconds: 3
  max_links: 2
```

- **`min_seconds`** — a submission sent sooner than this after the form was shown is spam. The form's definition
  carries a signed `timestamp`, which `useNibbleForm` posts back as `_nibble_t`; a theme that builds its own form posts
  it as a hidden `_nibble_t` input. A submission without a valid one is spam, so a theme has to send it. A page showing
  such a form is rendered for each visit rather than kept in the page cache, so each visitor's timestamp is their own.
- **`max_links`** — a submission whose `text` and `textarea` fields hold more than this many links between them is
  spam. `0` allows none.

A submission caught by the honeypot, `min_seconds` or `max_links` looks sent to whoever sent it. On a form that
stores submissions, its values are kept with the status **Spam**, its files never are, and nothing is emailed,
delivered or handled. The form's submissions screen shows **All but spam**, and **Spam** lists what was caught.
Someone who can edit the form can open a wrongly caught submission and choose **Not spam**: it becomes a received
submission, and its notifications, API deliveries and handler run once, as they would have when it was sent. Its
values still have to pass the form's checks.

Spam is deleted after 30 days, or after `spam.retention_days`:

```yaml
spam:
  retention_days: 7
```

A public demo form on a startup's site will still attract determined bots. Turn on a CAPTCHA:

```yaml
spam:
  captcha: true
  rate_limit:
    requests: 3
    per_minutes: 10
```

Then choose the provider — Cloudflare Turnstile or Google reCAPTCHA — and paste its keys under
**Globals → Integrations**. Google reCAPTCHA v3 scores each visitor from 0.0 (likely a bot) to 1.0, and a submission scoring below the
**Minimum score** there, 0.5 unless set, is refused. The theme's form component renders the widget from the form's definition. Nibble checks
each token with the provider's own verification address, which `outbound.allowed_hosts` doesn't need to list.

A theme receives `captcha` on the form: `null` when the form has no `captcha: true`, `{ provider, site_key }` when the
keys are set, and `{ provider: null, site_key: null }` when the form asks for a CAPTCHA but Integrations has no keys.
`useNibbleForm` loads no widget for the last case, and a theme can draw a placeholder or a notice there.

> [!WARNING]
> With `captcha: true` and no keys in Integrations, submissions cannot be verified and are refused. Add the keys
> before you deploy the change.

## 2. How long submissions are kept

```yaml
retention_days: 90
```

Submissions older than that are deleted on a schedule, so a contact form does not quietly accumulate people's
personal details for years. `store: false` keeps nothing at all — the email and API deliveries still happen.

Spam goes sooner: after `spam.retention_days`, 30 by default, or after `retention_days` when that is shorter.

A form removed from the schema keeps its stored submissions only for a while. The daily purge remembers each form's
last `retention_days` and keeps applying it to the submissions left behind; a form that had none loses them 30 days
after the purge first finds the form missing. `bin/rails nibble:check` warns while such submissions are stored.

An administrator can find, export or erase everything held about one email address, across every form, from
**Forms → Personal data** in the Control Plane. The export includes forms saved to finish later that mention the address, marked
`saved`, and never their link. The audit log records each export, erasure and submission delete
without storing the address. Visitors' IP addresses are never stored, only a keyed hash of them.

## 3. Encrypting a field

A field with `encrypt: true` is stored encrypted, with a key derived from the site's `secret_key_base` and bound to
its submission and field, so the database, a snapshot or a backup alone never shows it:

```yaml
  - handle: phone
    field: { type: text, display: Phone, encrypt: true }
```

Nibble decrypts it wherever it reads the submission: the Control Plane, CSV exports, emails, API deliveries and
handlers. The log of each API request shows `[secret]` in its place. A `files` field can't be encrypted, and neither
can a field on a form with `store: false`; `nibble:check` refuses both. The submissions screen's search doesn't look
inside encrypted values. **Personal data** does: it decrypts every submission that has encrypted values as it scans, so
it slows as those submissions grow. If `secret_key_base` changes, encrypted values can no longer be read.

> [!NOTE]
> Ninety days suits a demo form: long enough for sales to follow up, short enough that the site does not become a
> second, forgotten CRM.

## 4. Limits and schedules

```yaml
limits:
  opens_at: "2026-11-01T09:00"
  closes_at: "2026-11-30T17:00"
  max_submissions: 100
  unique: [email]
  closed_message: Registration has closed.
```

`opens_at` and `closes_at` are quoted dates and times in the site's time zone (`config.time_zone` in
`config/application.rb`, UTC unless set), or carry their own offset (`"2026-11-01T09:00+10:00"`). Before `opens_at`,
from `closes_at`, and once `max_submissions` submissions are stored, the form is closed: a submission is refused with
`closed_message` as its `base` error ("This form isn't taking submissions right now." unless set), and the form's
definition has `closed: true` and `closed_message`, so a theme can show the message instead of the form. Spam doesn't
count towards `max_submissions`.

`unique` lists fields whose value is accepted once: a second submission with the same value is refused with an error
on that field, "The Email has already been used.", or the field's `messages.unique`. A value that looks like an email
address matches whatever its case. Nibble keeps a keyed digest of each value, never the value, from when a submission
is accepted, so `unique` covers submissions accepted after it is added. Deleting a submission frees its values; spam
never holds one, and neither does a submission the form's API turned back. **Not spam** refuses a submission whose
value has been used since. A `unique` field is a `text`, `textarea`, `integer`, `decimal`, `select`, `radio` or `date` field.

`max_submissions` and `unique` need the form to store submissions. A page showing a form with `opens_at`, `closes_at`
or `max_submissions` is rendered for each visit rather than kept in the page cache, so it opens and closes on time.
`nibble:check` refuses a time it can't read, a `closes_at` before `opens_at`, and a key `limits` doesn't take.


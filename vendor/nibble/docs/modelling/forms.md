---
id: modelling-forms
title: Forms
description: Declare a public form, keep spam out, email the right people, pass submissions to another system, and
  decide how long they are kept.
order: 5
---

# Forms

Tidewater's "Book a demo" form is how sales hears about new customers, so it has to work, reach the right inbox,
land in the CRM and keep bots out. This guide covers all of that.

After reading this guide, you will know:

- How to declare a form and which fields a public form may use.
- How to put a form on a page.
- How spam protection works, and how to turn on a CAPTCHA.
- How to email submissions, and how to send them to another system's API.
- How long submissions are kept, and how to change it.

## 1. Declaring a form

```sh
bin/rails nibble:generate:form demo
```

```yaml
# site/schema/forms/demo.yml
title: Book a demo
fields:
  - handle: name
    field: { type: text, display: Your name, required: true }
  - handle: email
    field: { type: text, input_type: email, display: Work email, required: true }
  - handle: company
    field: { type: text, display: Company }
  - handle: team_size
    field:
      type: select
      display: Team size
      options: { solo: Just me, small: 2–10, large: More than 10 }
success:
  message: Thanks — we'll be in touch within a working day.
```

Fields are declared exactly as in a [blueprint](blueprints.md), but a public form may only use `text`, `textarea`,
`integer`, `toggle`, `select`, `radio`, `checkboxes`, `date` and `files`. `nibble:check` refuses anything else.

A consent box is a `required` toggle. A submission with it unticked is refused with "The Consent field is required.",
or the field's `messages.required`:

```yaml
  - handle: consent
    field:
      type: toggle
      display: Consent
      inline_label: I agree to be contacted about my enquiry
      required: true
      messages:
        required: Please tick the box so we can reply
```

`validate: [accepted]` refuses an unticked box too, saying "The Consent field must be accepted."

A field's `messages` set the text a visitor sees when one of its rules fails, per locale if the site has several; see
[Options every field takes](blueprints.md#2-options-every-field-takes).

`text` and `integer` fields take `prepend` and `append`, short text a theme draws before and after the input
(`prepend: $`, `append: per month`).

An `integer` field's `min`, `max` and `step` reach the theme, which draws a number input with them. On a public form
Nibble also refuses a value that is off the step, counted from `min` (or 0): with `min: 2000` and `step: 500`, 2250 is
refused and 2500 is accepted. The field's `messages.step` sets the wording, with `%{attribute}`, `%{step}` and `%{min}`. In a blueprint, `step` is only a hint to the input.

A field's other settings reach the theme too: a `text` field's `autocomplete`, a `textarea`'s `rows`, a `toggle`'s
`inline_label` (the text beside a consent box), a `date`'s `time_enabled`, `earliest_date` and `latest_date`, and a
`select`'s `max_items` and `clearable`. A field's `default` arrives resolved, so `default: computed:today` is today's
date.

A form field takes the same [conditions](blueprints.md#6-conditional-fields) as a blueprint field. Nibble skips a hidden
field's rules when a submission arrives, and it sends the theme each field's condition as `conditions`:

```json
{ "show": true, "match": "all", "rules": [{ "field": "kind", "operator": "equals", "value": "business" }] }
```

`show` is `true` for `if` and `show_when`, and `false` for `unless` and `hide_when`; `match` is `any` for the `_any`
forms and `all` otherwise. A field with no condition has no `conditions`. A theme draws the field when the rules pass
(`show: true`) or fail (`show: false`), and takes `match` to mean every rule or at least one. Each rule reads the
current value of `field`, and `value` is the text written in the schema:

| `operator` | Passes when |
|---|---|
| `equals`, `not` | the value is, or isn't, equal: `true`, `false` and `null` stand for those values, `empty` for a blank value (`null`, `""`, `[]`), and two numbers compare as numbers |
| `===`, `!==` | the same, without converting types |
| `>`, `>=`, `<`, `<=` | both sides are numbers and the comparison holds |
| `contains` | a list includes `value`, or a string contains it |
| `contains_any` | a list includes one of the comma-separated items in `value`, or a string contains one |
| `custom` | a condition written in Ruby; its `field` can be `null` |

A theme can't run `custom`, so it draws that field and leaves the decision to the server. `useNibbleForm`'s
`isVisible(field)` evaluates the rest as the server does, and the form leaves a field they hide out of what it posts;
`crumbs`' contact form draws only the fields whose conditions hold. The server is always the authority: it applies the
same conditions to every submission, whatever the theme drew.

A field with `hidden: true` is never shown to the visitor; `crumbs`' contact form sends it as an
`<input type="hidden">`. Give it a fixed `value`, a `prefill` from the page's query
string, or both, to record where a visitor came from:

```yaml
- handle: source
  field: { type: text, hidden: true, prefill: { query: utm_source }, value: direct }
- handle: channel
  field: { type: text, hidden: true, value: web }
```

A hidden field is validated, stored, emailed and delivered like any other. With a `prefill`, the value is the page's
`?utm_source=` when it has one, then what the form posts, then `value`. With only a `value`, Nibble stores that value
whatever is posted. The definition marks the field `hidden: true` and carries the resolved `value` for the current
request, and the form's `action` carries the prefilled query (`/forms/demo?utm_source=news`), so a theme that forgets a
hidden field still records it. A page that declares a prefill is cached once per value of that query parameter.
`nibble:check` refuses `prefill` or `value` on a field that isn't `hidden: true`, and a hidden `files` field.

A long form can be split into sections instead of one `fields` list. Each section has a `display`, optional
`instructions` and its own `fields`, declared the same way:

```yaml
title: Book a demo
sections:
  - display: Your details
    instructions: So we know who to call.
    fields:
      - handle: name
        field: { type: text, display: Your name, required: true }
      - handle: email
        field: { type: text, input_type: email, display: Work email, required: true }
  - display: Your team
    fields:
      - handle: team_size
        field: { type: integer, display: People, append: seats }
```

Sections only change how a theme lays the form out. Submissions, validation, storage and notifications see one
list of fields in order. Give `fields` or `sections`, not both; `nibble:check` reports it.

`success` is either a `message` shown in place of the form, or a `redirect` to a thank-you page:

```yaml
success:
  redirect: /demo/thanks
```

> [!TIP]
> A `files` field takes uploads — a brief, a logo — with `max_files`, `max_file_size` (in MB) and `extensions` to
> limit them. Uploaded files are kept with the submission.

## 2. Putting it on a page

A view asks for the form in its query sidecar, and renders it:

```yaml
# site/themes/tidewater/views/demo.yml
form:
  from: form:demo
```

The view receives the form's definition — its fields, where to post, the honeypot, the CAPTCHA — and
`useNibbleForm` does the posting and error handling. See [Theme components](../theming/components.md#6-forms) for
a complete form component.

A form posted without JavaScript that fails validation sends the visitor back to the page, and the form's `result` holds
their `errors` and the `values` they typed, and `useNibbleForm` starts the form from them. `values` leaves out files, hidden
fields, password inputs and the honeypot, and drops what wouldn't fit in the session cookie (about 2 KB in all). It is
there only for the one page load after the post.

The form posts to `POST /forms/demo`. Submissions are stored and listed under **Forms** in the Control Plane.

![Submissions to the Book a demo form](../../images/cp/form-submissions.png)

## 3. Emailing submissions

```yaml
notify:
  - to: sales@tidewater.example
    reply_to: email
  - to: founders@tidewater.example
    fields: [name, company, team_size]
```

Each entry sends one email per submission. `reply_to` names a field, so pressing Reply answers the person who
filled the form in. `fields` limits what that email includes.

An entry can also set who it goes to and what it says without code:

```yaml
notify:
  - to: "{global.contact.email}"
    subject: "{form.title} from {field.name}"
    message: "{field.name} asked about {field.topic}."
    if: { topic: support }
  - to: "{field.email}"
    subject: "We got your message, {field.name}"
    message: "Thanks for writing. We reply within a working day."
    fields: [message]
```

- `subject` and `message` (text shown above the fields) merge `{field.<handle>}` (the value as the submission shows
  it), `{form.title}` and `{global.<set>.<field>}`. Values are escaped in the email.
- `to`, `cc` and `bcc` take an address, `{field.<handle>}` or `{global.<set>.<field>}`. A field reference is the
  visitor's own address, so the entry is a confirmation; it needs a single valid email address, and an entry whose
  recipients are all invalid is skipped and logged on the submission. A global reference lets an editor change the
  recipient under **Globals** without a deploy.
- `if` sends the entry only when the submission matches, with the same conditions fields use (`if`, `if_any`,
  `unless`, `unless_any`), so `if: { topic: support }` routes support questions to one inbox and `if: { topic: sales }`
  to another.

Emails to staff link to the submission in the Control Plane; a confirmation to the visitor does not. Each attempt is
recorded on the submission (who it went to, when, sent, skipped or failed and the error), and **Send notifications
again** on a submission sends them again for anyone who can edit the form. `bin/rails nibble:check` flags a
reference to a field or global that doesn't exist.

> [!IMPORTANT]
> The address mail is sent *from* is a site setting: **Globals → Integrations**. Set it, and the SMTP settings in
> [configuration](../running/configuration.md#6-environment-and-credentials), before relying on email.

`cp_notify: true` also notifies Control Plane users who can see the form's submissions.

## 4. Spam

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
**Globals → Integrations**. The theme's form component renders the widget from the form's definition. Nibble checks
each token with the provider's own verification address, which `outbound.allowed_hosts` doesn't need to list.

A theme receives `captcha` on the form: `null` when the form has no `captcha: true`, `{ provider, site_key }` when the
keys are set, and `{ provider: null, site_key: null }` when the form asks for a CAPTCHA but Integrations has no keys.
`useNibbleForm` loads no widget for the last case, and a theme can draw a placeholder or a notice there.

> [!WARNING]
> With `captcha: true` and no keys in Integrations, submissions cannot be verified and are refused. Add the keys
> before you deploy the change.

## 5. Sending submissions to another system

Tidewater's sales team lives in its CRM, so each demo request should arrive there too. An `api` delivery posts the
submission to another system's API:

```yaml
api:
  - url: https://api.crm.example/v1/leads
    method: post
    format: json
    body:
      name: "{field.name}"
      email: "{field.email}"
      company: "{field.company}"
      source: website-demo
      token: "{secret.crm_token}"
```

`{field.x}` is a submitted value, `{secret.x}` a secret, and `{config.x}` a value from `outbound.config` in
[configuration](../running/configuration.md). Deliveries are `async` by default: the visitor sees the success message
at once, and a failed delivery is retried and shown on the submission in the Control Plane. `mode: sync` makes the
visitor wait for it instead.

A delivery counts as rejected, rather than failed, when the other system answers 400 or 422. A failed delivery is
retried; a rejected one is not, because sending the same data again would get the same answer. List other statuses
under `errors.status` to change which answers are rejections:

```yaml
api:
  - url: https://api.crm.example/v1/leads
    mode: sync
    errors:
      status: [400, 409, 422]
      path: errors
```

Nibble reads the field errors out of the JSON the other system returns. `errors.path` is where they are, as dotted
keys (`data.errors`); without it Nibble reads the top-level `errors`. They can be an object of `field: message`, or a
list of `{ field, message }` objects, and `errors.field` and `errors.message` name those two keys if the other system
calls them something else. A field name that is not one of the form's fields is shown as a general error on the form.
If the other system's names differ from yours, `error_fields` renames them: `error_fields: { email_address: email }`.

With `mode: sync` a rejection puts those messages on the visitor's form, beside the matching fields, and the
submission is not reported as a success. With `mode: async` the visitor has already seen the success message, so a
rejection is shown on the submission in the Control Plane instead.

Nibble only calls out to hosts you allow, and only uses secrets you name:

```yaml
# config/nibble.yml
outbound:
  allowed_hosts: [api.crm.example]
  secrets: [crm_token]
```

and the secret itself goes in the environment as `NIBBLE_SECRET_CRM_TOKEN`, or in credentials under
`nibble.secrets.crm_token`.

> [!CAUTION]
> Never put a key in the form file itself. Schema is committed to git and readable by anyone with the repository;
> `{secret.…}` keeps the key out of it.

### 5.1 API connections

When several forms call the same API, describe it once in `site/schema/apis/crm.yml`:

```yaml
base_url: https://api.crm.example/v1
headers:
  Authorization: "Bearer {secret.crm_token}"
timeout: 10
```

and deliver to it with `use: crm` instead of `url:`, adding the path to call with `path:`.

`base_url`, like the path and the headers, can use `{config.x}` and `{secret.x}`, so the address can differ per
environment without editing the schema:

```yaml
base_url: "{config.crm_url}/v1"
```

with `crm_url` set under `outbound.config` in `config/nibble.yml`. The rendered address is still checked against
`outbound.allowed_hosts`.

A connection can hold the `errors` mapping described above, so every form that uses it reads rejections the same
way; a delivery's own `errors` keys win over the connection's.

### 5.2 Handlers in Ruby

For anything a template cannot express, a form can name a `handler` registered in Ruby. See
[Extending Nibble](../extending/index.md).

## 6. How long submissions are kept

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
**Forms → Personal data** in the Control Plane; the audit log records each export, erasure and submission delete
without storing the address. Visitors' IP addresses are never stored, only a keyed hash of them.

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

### 6.1 Limits and schedules

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
value has been used since. A `unique` field is a `text`, `textarea`, `integer`, `select`, `radio` or `date` field.

`max_submissions` and `unique` need the form to store submissions. A page showing a form with `opens_at`, `closes_at`
or `max_submissions` is rendered for each visit rather than kept in the page cache, so it opens and closes on time.
`nibble:check` refuses a time it can't read, a `closes_at` before `opens_at`, and a key `limits` doesn't take.

## 7. Translating a form

On a site with several [locales](../running/configuration.md), any of a form's visitor-facing text may be a map of
locale to text instead of a string:

```yaml
title: { en: Say hello, fr: Dites bonjour }
success:
  message: { en: Thanks, fr: Merci }
sections:
  - display: { en: You, fr: Vous }
    fields:
      - handle: topic
        field:
          type: select
          display: { en: Topic, fr: Sujet }
          placeholder: { en: Choose one, fr: Choisissez }
          options:
            - value: sales
              label: { en: Sales, fr: Ventes }
```

This works for the form's `title`, `success.message` and `limits.closed_message`, a section's `display` and `instructions`, and a field's
`display`, `instructions`, `placeholder`, `inline_label` and option `label`s. The theme receives the text for the
page's locale, or the default locale's where a language is missing, or the first given. Option `value`s are the same in
every language, so stored submissions are too. `bin/rails nibble:check` refuses a map that names a locale the site
doesn't have.

The text Nibble itself shows a visitor is translated through Rails I18n, with English as the default. Add keys to the
site's `config/locales/<locale>.yml`:

| Key | Shown when |
|---|---|
| `nibble.forms.rate_limited` | a visitor submits too often; takes `one` and `other` forms with `%{count}` minutes |
| `nibble.forms.captcha_failed` | the CAPTCHA wasn't passed |
| `nibble.forms.captcha_unavailable` | the form needs a CAPTCHA the site hasn't set up |
| `nibble.forms.client.too_large` | the browser can't send the files |
| `nibble.forms.client.generic` | the answer had no message to show |
| `nibble.forms.client.network` | the request didn't reach the site |

A field's failed rules say "The Courriel field is required." in the field's `display` for the visitor's language; the
sentence itself is translated through `nibble.validation.*`, or by the field's own [`messages`](#1-declaring-a-form).
The client messages reach the theme as the definition's `messages`, which `useNibbleForm` shows.

Emails to staff are in the site's default locale. An email to the visitor, with `to: "{field.email}"`, uses the locale
the visitor submitted from: the form title, field labels and option labels in it follow that language.

## 8. Every key

| Key | Notes |
|---|---|
| `title` | **required**; a string or a map of locale to text |
| `fields`, `sections` | **one is required**; `sections` is a list of `{ display, instructions, fields }` |
| `success` | `{ message }` or `{ redirect }`; the message may be `{global.<set>.<field>}` |
| `notify` | a list of `{ to, cc, bcc, subject, message, reply_to, fields, if }` |
| `api` | a list of `{ url or use, path, method, format, body, mode, errors, error_fields, retry }`; `errors` is `{ status, path, field, message }`, and a connection in `site/schema/apis/` takes `base_url`, `headers`, `timeout`, `errors` and `retry` |
| `spam` | `{ honeypot, rate_limit: { requests, per_minutes }, captcha, min_seconds, max_links, retention_days }` |
| `store`, `cp_notify` | true / false |
| a field's `encrypt` | true stores its value encrypted; not on `files`, nor with `store: false` |
| `retention_days` | a positive number |
| `limits` | `{ opens_at, closes_at, max_submissions, unique, closed_message }` |
| `handler` | the name of a registered Ruby handler |

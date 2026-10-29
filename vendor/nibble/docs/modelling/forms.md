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

A field's `messages` set the text a visitor sees when one of its rules fails, per locale if the site has several; see
[Options every field takes](blueprints.md#2-options-every-field-takes).

`text` and `integer` fields take `prepend` and `append`, short text a theme draws before and after the input
(`prepend: $`, `append: per month`).

An `integer` field's `min`, `max` and `step` reach the theme, which draws a number input with them. On a public form
Nibble also refuses a value that is off the step, counted from `min` (or 0): with `min: 2000` and `step: 500`, 2250 is
refused and 2500 is accepted. In a blueprint, `step` is only a hint to the input.

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

> [!IMPORTANT]
> The address mail is sent *from* is a site setting: **Globals → Integrations**. Set it, and the SMTP settings in
> [configuration](../running/configuration.md#6-environment-and-credentials), before relying on email.

`cp_notify: true` also notifies Control Plane users who can see the form's submissions.

## 4. Spam

Every form gets two protections without asking:

- **A honeypot** — a hidden field people never fill in and bots usually do. Rename it with `spam.honeypot`, or turn
  it off with `honeypot: false`.
- **Rate limiting** — five submissions a minute from one address by default.

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

> [!NOTE]
> Ninety days suits a demo form: long enough for sales to follow up, short enough that the site does not become a
> second, forgotten CRM.

## 7. Every key

| Key | Notes |
|---|---|
| `title` | **required** |
| `fields`, `sections` | **one is required**; `sections` is a list of `{ display, instructions, fields }` |
| `success` | `{ message }` or `{ redirect }` |
| `notify` | a list of `{ to, reply_to, fields }` |
| `api` | a list of `{ url or use, path, method, format, body, mode, errors, error_fields, retry }`; `errors` is `{ status, path, field, message }`, and a connection in `site/schema/apis/` takes `base_url`, `headers`, `timeout`, `errors` and `retry` |
| `spam` | `{ honeypot, rate_limit: { requests, per_minutes }, captcha }` |
| `store`, `cp_notify` | true / false |
| `retention_days` | a positive number |
| `handler` | the name of a registered Ruby handler |

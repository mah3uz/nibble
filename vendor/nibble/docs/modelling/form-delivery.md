---
id: modelling-form-delivery
title: Form delivery
description: Email a form's submissions to the right people, pass them to another system's API or a Ruby handler, and
  see what was delivered.
order: 7
---

# Form delivery

A submission is stored, and then it goes where it is needed: an inbox, a CRM, a Ruby handler. This guide covers the
three, how a failed delivery is retried and where to see what happened. To declare the form itself, see
[Forms](forms.md).

After reading this guide, you will know:

- How to email submissions, to staff and to the visitor.
- How to send submissions to another system's API, and what happens when it refuses them.
- How to describe an API once and share it between forms.
- Where a delivery's result is recorded.

## 1. Emailing submissions

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
> The address mail is sent *from* is a site setting: **Site settings → Integrations**. Set it, and the SMTP settings in
> [configuration](../running/configuration.md#6-environment-and-credentials), before relying on email.

`cp_notify: true` also notifies Control Plane users who can see the form's submissions.

## 2. Sending submissions to another system

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

### 2.1 What a delivery takes

| Key | Meaning |
|---|---|
| `url` or `use` | **one of them.** `url` is an absolute `http(s)` address; `use` names an [API connection](#22-api-connections) |
| `path` | with `use`, the path to call under the connection's `base_url` |
| `method` | `post` (the default), `put` or `patch` |
| `format` | how the body is sent: `json` (the default) or `form` (`application/x-www-form-urlencoded`) |
| `body` | a map of what to send; its values may use `{field.x}`, `{secret.x}`, `{config.x}` and `{global.<set>.<field>}`. Without `body`, the whole submission is sent as a map of handle to value |
| `mode` | `async` (the default) or `sync` |
| `errors`, `error_fields` | which answers are rejections and where the field errors are, as above |
| `retry` | `{ attempts, backoff_seconds }`: how many times in all a failed delivery is tried (3 unless set) and the wait before the second try (30 seconds unless set), which doubles each time |

A delivery with a bare `url` sends only Nibble's own headers and waits up to 10 seconds. To send a header such as
`Authorization`, or to change the timeout, use an API connection. A connection's `retry` is the default for every
delivery that uses it, and a delivery's own `retry` wins.

Each delivery is recorded on the submission, with its status (pending, delivered, rejected or failed), the response
status and the error, and the Control Plane can send a failed one again.

### 2.2 API connections

When several forms call the same API, describe it once in `site/schema/apis/crm.yml`:

```yaml
base_url: https://api.crm.example/v1
headers:
  Authorization: "Bearer {secret.crm_token}"
timeout: 10
```

and deliver to it with `use: crm` instead of `url:`, adding the path to call with `path:`. `timeout` is how many
seconds a request waits, 10 unless set.

`base_url`, like the path and the headers, can use `{config.x}` and `{secret.x}`, so the address can differ per
environment without editing the schema:

```yaml
base_url: "{config.crm_url}/v1"
```

with `crm_url` set under `outbound.config` in `config/nibble.yml`. The rendered address is still checked against
`outbound.allowed_hosts`.

A connection can hold the `errors` mapping described above, so every form that uses it reads rejections the same
way; a delivery's own `errors` keys win over the connection's.

### 2.3 Handlers in Ruby

For anything a template cannot express, a form can name a `handler` registered in Ruby. See
[Extending Nibble](../extending/index.md).


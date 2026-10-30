---
id: modelling-form-keys
title: Every form key
description: Every key a form file takes, nested keys included, with its type, its default and the guide that explains it.
order: 10
---

# Every form key

A form lives in `site/schema/forms/<handle>.yml`. This page lists every key it takes, one row each, with nested keys
written as a path (`spam.rate_limit.requests` is `requests` under `rate_limit` under `spam`). `bin/rails nibble:check`
refuses a form with a key not listed here, a key of the wrong type or a value it can't use.

"Text" in the Type column means a string, or a map of locale to string on a site with several
[locales](form-translation.md).

## 1. The form

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `title` | text | **required** | the form's name, shown to visitors and in emails | [Forms](forms.md#1-declaring-a-form) |
| `fields` | list | | the form's fields, in order; give `fields` or `sections`, not both | [Forms](forms.md#1-declaring-a-form) |
| `sections` | list | | groups of fields; each is `{ display, instructions, fields }` | [Forms](forms.md#1-declaring-a-form) |
| `steps` | true / false | `false` | each section becomes a step; needs `sections` | [Steps](forms.md#15-steps-and-finishing-later) |
| `submit_label` | text | the theme's "Send message" | the send button's text | [Translating](form-translation.md) |
| `success` | map | | what the visitor sees after sending | [Forms](forms.md#1-declaring-a-form) |
| `success.message` | text | | shown in place of the form; may use `{global.<set>.<field>}` | [Forms](forms.md#1-declaring-a-form) |
| `success.redirect` | text | | an on-site path or an `http(s)` address to send the visitor to | [Forms](forms.md#1-declaring-a-form) |
| `store` | true / false | `true` | keep submissions; `false` keeps nothing, and emails and deliveries still happen | [Retention](form-spam-and-privacy.md#2-how-long-submissions-are-kept) |
| `retention_days` | whole number | kept until deleted | delete submissions older than this many days | [Retention](form-spam-and-privacy.md#2-how-long-submissions-are-kept) |
| `cp_notify` | true / false | `false` | notify Control Plane users who can see the form's submissions | [Delivery](form-delivery.md#1-emailing-submissions) |
| `handler` | text | | the name of a registered Ruby handler | [Handlers](form-delivery.md#23-handlers-in-ruby) |

## 2. Finishing later

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `resume` | true / false | `false` | adds **Save and finish later**; needs `store` on | [Steps](forms.md#15-steps-and-finishing-later) |
| `resume_email` | text | | the handle of the `text` field that holds the visitor's address | [Steps](forms.md#15-steps-and-finishing-later) |
| `resume_days` | whole number | `7` | how many days the link works | [Steps](forms.md#15-steps-and-finishing-later) |

## 3. Emailing: `notify`

`notify` is a list; each entry sends one email per submission.

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `notify.to` | address or list | **required** | who gets it: an address, `{field.<handle>}` or `{global.<set>.<field>}` | [Delivery](form-delivery.md#1-emailing-submissions) |
| `notify.cc`, `notify.bcc` | address or list | | copies, written like `to` | [Delivery](form-delivery.md#1-emailing-submissions) |
| `notify.subject` | text | "New submission: title" | the subject; merges `{field.x}`, `{form.title}` and `{global.set.field}` | [Delivery](form-delivery.md#1-emailing-submissions) |
| `notify.message` | text | | text shown above the fields; merges like `subject` | [Delivery](form-delivery.md#1-emailing-submissions) |
| `notify.reply_to` | field handle | | the field whose address Reply answers | [Delivery](form-delivery.md#1-emailing-submissions) |
| `notify.fields` | list of field handles | every field | what the email includes | [Delivery](form-delivery.md#1-emailing-submissions) |
| `notify.if`, `notify.if_any`, `notify.unless`, `notify.unless_any`, `notify.show_when`, `notify.show_when_any`, `notify.hide_when`, `notify.hide_when_any` | map of field handle to value | | send the entry only when the submission matches | [Delivery](form-delivery.md#1-emailing-submissions) |

## 4. Other systems: `api`

`api` is a list; each entry is one delivery.

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `api.url` | text | | an absolute `http(s)` address; give `url` or `use` | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.use` | text | | the handle of an API connection | [Connections](form-delivery.md#22-api-connections) |
| `api.path` | text | | with `use`, the path under the connection's `base_url` | [Connections](form-delivery.md#22-api-connections) |
| `api.method` | `post`, `put`, `patch` | `post` | the HTTP method | [A delivery](form-delivery.md#21-what-a-delivery-takes) |
| `api.format` | `json`, `form` | `json` | how the body is encoded | [A delivery](form-delivery.md#21-what-a-delivery-takes) |
| `api.body` | map | the whole submission | what to send; values merge `{field.x}`, `{secret.x}`, `{config.x}` | [A delivery](form-delivery.md#21-what-a-delivery-takes) |
| `api.mode` | `async`, `sync` | `async` | `sync` makes the visitor wait and shows a rejection on the form | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.errors` | map | | how to read a rejection | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.errors.status` | list of numbers | `[400, 422]` | the answers that count as rejected, not failed | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.errors.path` | dotted keys | `errors` | where the field errors are in the JSON answer | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.errors.field`, `api.errors.message` | text | `field`, `message` | the two keys of an error written as `{ field, message }` | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.error_fields` | map | | renames the other system's field names to the form's | [Delivery](form-delivery.md#2-sending-submissions-to-another-system) |
| `api.retry` | map | | how a failed delivery is retried | [A delivery](form-delivery.md#21-what-a-delivery-takes) |
| `api.retry.attempts` | whole number | `3` | tries in all | [A delivery](form-delivery.md#21-what-a-delivery-takes) |
| `api.retry.backoff_seconds` | whole number | `30` | the wait before the second try; it doubles each time | [A delivery](form-delivery.md#21-what-a-delivery-takes) |

An API connection is its own file in `site/schema/apis/<handle>.yml`:

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `base_url` | text | **required** | the address paths are added to; may use `{config.x}` and `{secret.x}` | [Connections](form-delivery.md#22-api-connections) |
| `headers` | map | | sent with every request; may use `{secret.x}` | [Connections](form-delivery.md#22-api-connections) |
| `timeout` | whole number | `10` | seconds a request waits | [Connections](form-delivery.md#22-api-connections) |
| `errors` | map | | the same as `api.errors`; a delivery's own keys win | [Connections](form-delivery.md#22-api-connections) |
| `retry` | map | `3` attempts, `30` seconds | the same as `api.retry`; a delivery's own keys win | [A delivery](form-delivery.md#21-what-a-delivery-takes) |

## 5. Spam: `spam`

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `spam.honeypot` | text or `false` | `_nibble_hp` | the hidden field's name; `false` turns it off | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.rate_limit` | map | | accepted submissions per address | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.rate_limit.requests` | whole number | `5` | submissions allowed in the window | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.rate_limit.per_minutes` | whole number | `1` | the window, in minutes | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.captcha` | true / false | `false` | require a CAPTCHA; keys are set under **Site settings → Integrations** | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.min_seconds` | whole number | off | a submission sent sooner than this after the form was shown is spam | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.max_links` | whole number | off | more links than this in the text fields is spam; `0` allows none | [Spam](form-spam-and-privacy.md#1-spam) |
| `spam.retention_days` | whole number | `30` | delete spam after this many days | [Spam](form-spam-and-privacy.md#1-spam) |

## 6. Limits: `limits`

| Key | Type | Default | Meaning | Explained in |
|---|---|---|---|---|
| `limits.opens_at` | quoted date and time | open | the form refuses submissions before this | [Limits](form-spam-and-privacy.md#4-limits-and-schedules) |
| `limits.closes_at` | quoted date and time | never | the form refuses submissions from this | [Limits](form-spam-and-privacy.md#4-limits-and-schedules) |
| `limits.max_submissions` | whole number | no cap | the form closes once this many are stored; spam doesn't count | [Limits](form-spam-and-privacy.md#4-limits-and-schedules) |
| `limits.unique` | list of field handles | | fields whose value is accepted once | [Limits](form-spam-and-privacy.md#4-limits-and-schedules) |
| `limits.closed_message` | text | "This form isn't taking submissions right now." | shown when the form is closed | [Limits](form-spam-and-privacy.md#4-limits-and-schedules) |

## 7. Keys on a form's fields

A form's fields are declared as in a [blueprint](blueprints.md), and these options matter on a form.

| Key | Explained in |
|---|---|
| a field's `encrypt` — `true` stores its value encrypted; not on `files`, nor with `store: false` | [Encrypting](form-spam-and-privacy.md#3-encrypting-a-field) |
| a field's `hidden`, `value` and `prefill` — a field the visitor never sees, with a fixed or query-string value | [Forms](forms.md#1-declaring-a-form) |
| a field's `messages` — the text shown when one of its rules fails, per locale | [Forms](forms.md#1-declaring-a-form) |
| a `text` field's `input_type` — `email`, `url` and `tel` check the value | [Text that is checked](forms.md#12-text-that-is-checked) |
| a `toggle` field's `inline_label` — text beside the box, which may hold Markdown links | [A consent checkbox](forms.md#13-a-consent-checkbox) |
| a `note` field's `text` — Markdown shown between fields; stores nothing | [Notes](forms.md#14-notes) |
| a `calculation` field's `formula`, `decimals`, `prepend`, `append` — the formula (**required**), places to round to (0–15), and text around the figure | [Calculations](forms.md#11-calculations) |
| a `decimal` field's `decimals`, `min`, `max`, `step`, `placeholder`, `prepend`, `append` — places kept (0–10, default 2), bounds, the input's step, and text in and around the input | [Forms](forms.md#1-declaring-a-form) |
| a `range` field's `min`, `max`, `step`, `default`, `prepend`, `append` — the scale (0, 100 and 1 by default), where it starts, and text around the value | [Forms](forms.md#1-declaring-a-form) |
| a `rating` field's `max` — the number of stars, 2–10 (default 5) | [Forms](forms.md#1-declaring-a-form) |
| a `files` field's `max_files`, `max_file_size` and `extensions` — limit uploads | [Forms](forms.md#1-declaring-a-form) |

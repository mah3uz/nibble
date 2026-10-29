---
id: modelling-forms
title: Forms
description: Declare a public form: its fields, sections, steps, calculations and success message, and put it on a page.
order: 5
---

# Forms

Tidewater's "Book a demo" form is how sales hears about new customers, so it has to work, reach the right inbox,
land in the CRM and keep bots out. This guide covers all of that. To draw a form in your theme, see [Forms in your theme](../theming/forms.md).

After reading this guide, you will know:

- How to declare a form and which fields a public form may use.
- How to split a long form into steps, and let a visitor save it and finish later.
- How to put a form on a page.
- Where to read about delivery, spam, privacy and translation, and where every form key is listed.

The rest of forms is in four more guides: [Form delivery](form-delivery.md), [Form spam and
privacy](form-spam-and-privacy.md), [Translating a form](form-translation.md) and [Every form key](form-keys.md).

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
`integer`, `decimal`, `range`, `rating`, `toggle`, `select`, `radio`, `button_group`, `checkboxes`, `date`, `time`,
`color`, `files`, [`calculation`](#11-calculations) and [`note`](#14-notes).
`nibble:check` refuses anything else.

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

`text`, `integer`, `decimal` and `range` fields take `prepend` and `append`, short text a theme draws before and after the input
(`prepend: $`, `append: per month`).

An `integer` field's `min`, `max` and `step` reach the theme, which draws a number input with them. On a public form
Nibble also refuses a value that is off the step, counted from `min` (or 0): with `min: 2000` and `step: 500`, 2250 is
refused and 2500 is accepted. The field's `messages.step` sets the wording, with `%{attribute}`, `%{step}` and `%{min}`. In a blueprint, `step` is only a hint to the input.

A `decimal` field keeps `decimals` places (0 to 10, default 2), rounding half away from zero, and stores a number; its
`min`, `max`, `step`, `decimals` and `placeholder` reach the theme, which draws a number input that steps by `step`, or by
the smallest step `decimals` allows. A `range` field is a slider with `min` (default 0), `max` (default 100), `step`
(default 1) and `default`, and a value outside `min` and `max` is refused. A `rating` field is a row of stars, `max` of them
(2 to 10, default 5); it stores a number from 1 to `max`, or nothing when the visitor leaves it unrated, and refuses
anything else:

```yaml
  - handle: budget
    field: { type: decimal, display: Budget, prepend: $, decimals: 2, min: 0 }
  - handle: urgency
    field: { type: range, display: How soon, min: 0, max: 10, append: " / 10" }
  - handle: service
    field: { type: rating, display: How was the service?, max: 5 }
```

A field's other settings reach the theme too: a `text` field's `autocomplete`, a `textarea`'s `rows`, a `toggle`'s
`inline_label` (the text beside a consent box), a `date`'s `time_enabled`, `earliest_date`, `latest_date` and `time_zone` (resolved, so `site` arrives as the
site's zone name; a visitor's local time is read in it), a
`time`'s `seconds`, `earliest` and `latest`, a `color`'s `swatches` and `allow_any`, and a
`select`'s `max_items` and `clearable`. A `button_group` carries its `options` as a `radio` does, and a
[calculation](#11-calculations) may name one whose options are all numbers. A field's `default` arrives resolved, so `default: computed:today` is today's
date.

A form field takes the same [conditions](../reference/conditions.md) as a blueprint field. Nibble skips a hidden
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

A hidden field's rules are skipped, but its value is not discarded: a value posted for a field its condition hides is
stored, emailed and delivered as posted, and `always_save: true` keeps the field's rules running while it is hidden. A
theme that wants the value gone leaves the field out of what it posts, as `useNibbleForm` does.

A field's `required` takes a condition too, with exactly one of the keys above: `required: { if: { contact_by: phone } }`
makes the field required while the condition passes and optional while it fails. A field its own conditions hide is never
required. The definition carries `required` as `true` or `false`, or, for a conditional one, as an object in the shape of
`conditions` (`show`, `match` and `rules`), where `show: true` means required while the rules pass. `useNibbleForm`'s
`isRequired(field)` answers it for the current answers, and `crumbs`' contact form uses it for the `*` marker, the
`required` attribute and the "Fields marked * are required" line. A theme can't run a `custom` rule, so it treats that
field as optional and the server decides.

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

### 1.1 Calculations

A `calculation` field shows a figure worked out from the visitor's other answers, such as the total of a quote:

```yaml
fields:
  - handle: seats
    field: { type: integer, display: Seats, min: 1 }
  - handle: seat_price
    field: { type: integer, hidden: true, value: 400 }
  - handle: support
    field:
      type: radio
      display: Support
      options: { 0: Standard, 150: Priority }
  - handle: onboarding
    field: { type: toggle, display: Add onboarding ($500) }
  - handle: total
    field:
      type: calculation
      display: Total
      formula: "{seats} * {seat_price} + {support} + {onboarding} * 500"
      decimals: 2
      prepend: $
```

The theme works the figure out again whenever the visitor changes an answer, so three seats with priority support show
"Total: $1,350.00". When the form is sent, Nibble calculates it from the submitted values, and that is the value it
stores, emails, exports and delivers; a value posted for a calculation is ignored.

A formula has:

- numbers, such as `12` and `0.5`;
- `{handle}` for another field of the form;
- `+`, `-`, `*` and `/`, with `*` and `/` first, and parentheses to group;
- a leading `-` to negate;
- `round(x)` to a whole number, `round(x, places)` to up to 15 decimal places, `min(a, b)` and `max(a, b)`.

Nothing else is read: there are no other functions, no text and no variables. A formula may name an `integer`, a `decimal`, a `range`, a `rating`, a
`toggle` (1 when ticked, 0 when not), a single-choice `select` or `radio` whose option values are all numbers, or
another calculation. A blank answer, and a field its [conditions](#1-declaring-a-form) hide, count as 0. Dividing by
zero leaves the calculation blank, and a blank calculation isn't stored.

`decimals` rounds the result, a half away from zero, and the figure is shown with exactly that many places. Without
`decimals` the value is kept as calculated. Both the browser and the server count in binary fractions, so `0.1 + 0.2`
is 0.30000000000000004 until `decimals: 2` rounds it to 0.3: give money a `decimals`. `prepend` and `append` frame the
figure wherever it's shown, so emails, the Control Plane and exports read "$1,350.00".

A calculation can have conditions of its own; while they hide it, it's blank and counts as 0. A condition can't read a
calculation, because a calculation isn't an answer the visitor posts. A calculation can't be `required` or `hidden`,
and only a form can have one. `nibble:check` refuses a formula that doesn't parse, one that names a field the form
doesn't have or one that doesn't hold a number, a calculation that depends on itself (directly or through other
calculations), `decimals` outside 0–15, and a calculation in a blueprint or global set.

### 1.2 Text that is checked

A `text` field with `input_type: email`, `url` or `tel` checks what the visitor typed, unless they left it blank: an
email address, an absolute `http://` or `https://` address, or a phone number made of digits, spaces and `+ ( ) . -`
with at least three digits. The messages are "must be a valid email address", "must be a valid URL" and "must be a valid
phone number", and a field's `messages` under `email`, `url` or `phone` replace them, per locale. A `validate: [ "regex:…" ]`
on a `tel` field replaces the phone check, so `regex:/^04\d{8}$/` accepts only Australian mobile numbers. See
[the fieldtypes](blueprints.md#3-the-fieldtypes).

### 1.3 A consent checkbox

A consent box is a `required` toggle whose `inline_label` links to the policy:

```yaml
  - handle: consent
    field:
      type: toggle
      display: Consent
      inline_label: I agree to the [privacy policy](/privacy) and the [terms](/terms)
      required: true
```

The label may be written per locale. A link may go to a web, email or phone address or a page on the site; any other
link is shown as its text. The theme receives `inline_label` as plain text with only the link text, and
`inline_label_html` with the links as `<a href rel="noopener">` when the label has any. Emails, the Control Plane's
submissions and CSV exports show the plain text.

### 1.4 Notes

A `note` field puts text between the fields, such as how replies are handled:

```yaml
  - handle: reply_time
    field:
      type: note
      text: We reply **within a working day**. Urgent? [Call us](tel:+61299991234).
```

`text` is Markdown, per locale if the site has several: paragraphs, emphasis, lists and links to web, email, phone or
site addresses. The theme receives it as `text_html`, already safe to draw as HTML. A note is not an answer: it is not
posted, stored, emailed, exported or delivered, it has no value for a condition to read, and it can't be `required`,
`hidden`, `encrypt`ed or have a `default`; `nibble:check` refuses those. It takes the other options a field does,
such as `display`, `width` and `conditions`.

### 1.5 Steps, and finishing later

`steps: true` on a sectioned form makes each section a step. The visitor sees one step at a time with a progress
indicator, Back and Next, and Next checks that step before moving on:

```yaml
title: Book a demo
steps: true
resume: true
resume_email: email
resume_days: 7
sections:
  - display: Your details
    fields:
      - handle: email
        field: { type: text, input_type: email, display: Work email, required: true }
  - display: Your team
    fields:
      - handle: team_size
        field: { type: integer, display: People, required: true }
```

Next posts what the visitor has entered to `POST /forms/demo/steps/<index>`, where `<index>` counts the form's sections
from 0. Nibble checks that section's fields as it checks a submission, conditions included, and answers
`{ "ok": true }` or `422` with the section's `errors`; nothing is stored, emailed or delivered. Step checks don't count
towards `spam.rate_limit`: they have a cap of their own, twenty times its `requests` in the same window. Sending the
form on the last step checks every field again, as for any submission. A step whose fields are all hidden by their
conditions is skipped. Without JavaScript the form is one long sectioned form, every step shown, and it is sent as
usual.

`resume: true` adds **Save and finish later**. It posts what the visitor has entered to `POST /forms/demo/resume`, and
Nibble emails the address in the field `resume_email` names a link back to the page the form is on,
`/demo?resume=<token>`. That page's definition then carries the saved values, and the form starts from them; it is
rendered for each visit rather than kept in the page cache. The link works for `resume_days`, 7 unless set; after
that, or once the form has been sent, the definition says the link has expired and the form starts empty.

What is saved is held like a submission's values, and only until the visitor comes back:

- Fields with `encrypt: true` are stored encrypted. Files never are: the visitor attaches them again.
- Only a digest of the link's token is stored, so the database alone can't open a saved form.
- A saved form is never a submission: it isn't listed, counted towards `limits`, emailed to anyone but the visitor,
  delivered or handled.
- Sending the form deletes it, and so does saving again from the same page, so a visitor holds one link. The daily
  purge deletes saved forms once they expire, and **Personal data** erases them with a person's submissions.
- Saving takes the form's honeypot, `min_seconds`, `max_links` and CAPTCHA like a submission does, and has its own
  `spam.rate_limit` count, so the form can't be used to send email in bulk. A save caught as spam looks saved and keeps
  nothing.

`nibble:check` refuses `steps: true` without `sections`, a `resume_email` that isn't one of the form's text fields,
and `resume` on a form with `store: false`.

## 2. Putting it on a page

A view asks for the form in its query sidecar, and renders it:

```yaml
# site/themes/tidewater/views/demo.yml
form:
  from: form:demo
```

The view receives the form's definition — its fields, where to post, the honeypot, the CAPTCHA — and
`useNibbleForm` does the posting and error handling. See [Forms in your theme](../theming/forms.md) for
a complete form component.

A form posted without JavaScript that fails validation sends the visitor back to the page, and the form's `result` holds
their `errors` and the `values` they typed, and `useNibbleForm` starts the form from them. `values` leaves out files, hidden
fields, password inputs and the honeypot, and drops what wouldn't fit in the session cookie (about 2 KB in all). It is
there only for the one page load after the post.

The form posts to `POST /forms/demo`. Submissions are stored and listed under **Forms** in the Control Plane.

![Submissions to the Book a demo form](../../images/cp/form-submissions.png)

## 3. Where next

| To | Read |
|---|---|
| email submissions, call another system's API or run a handler | [Form delivery](form-delivery.md) |
| keep bots out, set a CAPTCHA, close the form on a date, cap it, or encrypt a field | [Form spam and privacy](form-spam-and-privacy.md) |
| decide how long submissions are kept, or find and erase one person's data | [Form spam and privacy](form-spam-and-privacy.md#2-how-long-submissions-are-kept) |
| write the form in several languages | [Translating a form](form-translation.md) |
| look up a key, its default and where it is explained | [Every form key](form-keys.md) |

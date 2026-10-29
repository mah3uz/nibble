---
id: modelling-form-translation
title: Translating a form
description: Write a form's text per locale, and translate the wording Nibble itself shows a visitor.
order: 9
---

# Translating a form


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
| `nibble.forms.client.choose`, `send`, `sending`, `next`, `checking`, `back`, `save_later` | the labels crumbs' form shows: the empty choice of a select, the submit button (and while it works), Next (and while it checks), Back, and Save and finish later |
| `nibble.forms.client.step`, `check_answers`, `required_note`, `required` | "Step %{step} of %{total}", the line above a list of errors, "Fields marked * are required." (the first `*` is drawn as the marker), and the hidden "(required)" read to screen readers |
| `nibble.forms.resume.saved` | a form was saved to finish later; takes `one` and `other` forms with `%{count}` days |
| `nibble.forms.resume.email` | a save has no valid address in the `resume_email` field |
| `nibble.forms.resume.failed` | the email with the link couldn't be sent |
| `nibble.forms.resume.too_large` | there is too much to save |
| `nibble.forms.resume.expired` | a link has expired or its form was sent |

A field's failed rules say "The Courriel field is required." in the field's `display` for the visitor's language; the
sentence itself is translated through `nibble.validation.*`, or by the field's own [`messages`](forms.md#1-declaring-a-form).
The client messages reach the theme as the definition's `messages`, which `useNibbleForm` shows; a theme draws its own
labels from them too.

A form's `submit_label` sets the text of its send button, per locale like other form text, in place of the theme's
"Send message".

Emails to staff are in the site's default locale. An email to the visitor, with `to: "{field.email}"`, uses the locale
the visitor submitted from: the form title, field labels and option labels in it follow that language. The wording
Nibble adds around them, and the email with a link to a saved form, is translated under `nibble.forms.mail.submission.*`
(`visitor_heading`, `staff_heading`, `visitor_intro`, `staff_intro`, `reply_to`, `open`, `subject`) and
`nibble.forms.mail.resume.*` (`heading`, `intro`, `intro_text`, `button`, `note`), with `%{title}`, `%{site}`,
`%{email}` and `%{expires}` where the text uses them.


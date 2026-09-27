---
id: extending-emails
title: Emails
description: The emails Nibble sends your team, and how to give them your own design and your own words.
order: 3
---

# Emails

Nibble sends a handful of emails: an invitation when someone is given an account, a link when they forget their
password, a form's submissions, and the notifications people ask for. They arrive in a plain, tidy design with your
site's name at the top. You can give them your own.

After reading this guide, you will know:

- Which emails Nibble sends, and to whom.
- How to change how every email looks with one file.
- How to change what one email says.
- How to see your changes without sending anything.

## 1. What Nibble sends

| Email | Sent when | To |
|---|---|---|
| **Invitation** | someone is given an account in **Users** | the new user |
| **Password reset** | someone asks for one on the sign-in screen, or an admin sends one | that user |
| **Form submission** | a form with a `notify` list is submitted | the addresses in [`notify`](../modelling/forms.md#3-emailing-submissions) |
| **Notification** | a review is requested, an entry is approved or sent back, someone is mentioned, a form is submitted, a webhook is turned off | the person it is for, unless they turned email notifications off |

Every email comes from the **Sender name** and **Sender address** in **Globals → Integrations**, and names the site with
the **Name** in **Globals → Site**.

## 2. Your own design

Every email is drawn inside one layout. Put a layout of your own at the same path in your site's `app/`, and it is
used instead of Nibble's:

```text
app/views/layouts/nibble/mailer.html.erb   # the HTML version
app/views/layouts/nibble/mailer.text.erb   # the plain-text version
```

A layout needs three things: the email's subject for its title, the site's name, and the email itself.

```erb
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= message.subject %></title>
    <style>
      .content h1 { font-size: 28px; color: #2a1250; }
      .content .button { display: inline-block; padding: 12px 24px; border-radius: 999px; background: #7b2ff7; color: #ffffff; text-decoration: none; }
    </style>
  </head>
  <body style="margin: 0; background: #fff5fa;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td align="center" style="padding: 32px 16px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width: 560px;">
            <tr><td style="padding-bottom: 16px; font: 700 20px Helvetica, Arial, sans-serif;"><%= site_name %></td></tr>
            <tr>
              <td class="content" style="padding: 32px; background: #ffffff; border-radius: 24px; font: 15px/1.6 Helvetica, Arial, sans-serif;">
                <%= yield %>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
```

The emails themselves are plain HTML, so the layout's `<style>` decides how they look. Each one uses only these:

| Element | Holds |
|---|---|
| `h1` | what the email is about |
| `p`, `strong`, `a` | the message |
| `a.button` | the one thing to do, such as choosing a password |
| `p.note` | the small print: when a link expires, what to do if it was not you |
| `blockquote` | a comment someone left |
| `table`, `th`, `td` | a form submission's fields and values |

`site_name` is the **Name** from **Globals → Site**, or "the site" until one is set.

> [!TIP]
> Email clients are not browsers. Lay the page out with tables, put the styles that matter most inline, and leave out
> scripts, SVG and positioning. Web fonts load in some clients and fall back in others, so always name a fallback.

## 3. Your own words

Each email is a pair of views, one HTML and one plain text. Put a view at the same path in your site's `app/` and it is
used instead of Nibble's:

| Email | Views |
|---|---|
| Invitation | `app/views/nibble/passwords_mailer/invite.html.erb`, `invite.text.erb` |
| Password reset | `app/views/nibble/passwords_mailer/reset.html.erb`, `reset.text.erb` |
| Form submission | `app/views/nibble/forms_mailer/submission.html.erb`, `submission.text.erb` |
| Notification | `app/views/nibble/notifications_mailer/notify.html.erb`, `notify.text.erb` |

Start from Nibble's copy in `vendor/nibble/app/views/` and change the words. Keep the links it builds: a password email
without its link cannot do its job.

> [!IMPORTANT]
> A view you replace is yours from then on. When a release improves that email, your copy does not change with it, so
> replace the layout for a new look and reach for a view only when the words have to change.

## 4. Seeing them without sending

Rails shows emails in the browser while the development server runs. Describe the ones you want to see in
`test/mailers/previews/`:

```ruby
# test/mailers/previews/passwords_mailer_preview.rb
class PasswordsMailerPreview < ActionMailer::Preview
  def invite = Nibble::PasswordsMailer.invite(Nibble::User.first)
  def reset = Nibble::PasswordsMailer.reset(Nibble::User.first)
end
```

Then open `/rails/mailers` on your development server, and pick one. Each shows the HTML and the plain text side by
side, with your layout around them.

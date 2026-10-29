---
id: editing-form-submissions
title: Form submissions
description: Read, search and export what people sent through the site's forms, and know where their emails go.
order: 5
---

# Form submissions

Every demo request Tidewater's site receives is kept, emailed to sales and listed in the Control Plane. This guide
is for whoever answers them.

After reading this guide, you will know:

- Where submissions are, and how to find one.
- How to mark one handled, keep it unread, and leave notes for your team.
- How to export them for a spreadsheet.
- Where notification emails come from, and what to check when they stop.
- How long submissions are kept.

## 1. Reading submissions

Open **Forms** in the sidebar and choose a form. Each has its own list, newest first:

![Submissions to the Book a demo form](../../images/cp/form-submissions.png)

Search and **Filters** narrow it; the columns button chooses which fields are shown. Open one to see everything that
was sent, when, and what happened to it — whether its emails went out and whether it reached any other system the
form sends to.

**Uploaded files** — a brief, a logo — are attached to the submission and open from it.

A submission can be deleted from its **…** menu once it has been dealt with.

### Handling

Every submission starts as **New**. Press **Mark handled** on its page, or select several in the list and choose
**Mark handled**, when someone has dealt with it; **Mark new** puts it back. The **Handling** filter shows only the
New or only the Handled ones, and a handled submission says who handled it and when. Opening a submission marks it
read; **Mark unread** brings it back to the unread count so you remember to return to it.

**Notes** on the submission page are for your team: who wrote each one and when is kept beside it, and visitors never
see them. Handling, unread and notes need permission to edit the form's submissions.

## 2. Exporting

**Export Submissions** downloads the lot as a CSV file for a spreadsheet — for an event's sign-ups, or a month of
demo requests for someone who does not use the Control Plane.

Exports and deletes are recorded in the audit log with who did them, which form and how many submissions.

> [!CAUTION]
> An export is people's names and email addresses on your laptop. Keep it only as long as you need it, and do not
> send it round by email.

## 3. Emails

A form can email people when it is submitted. Tidewater's sends each demo request to `sales@`, and pressing Reply
answers the person who asked. Who receives what is part of the form's setup; the address mail is sent **from** is a
site setting under **Globals → Integrations**.

If emails stop arriving:

1. Check the submission is in the list. If it is, the form is working.
2. Open it: it lists each email with who it went to and whether it was sent, skipped or failed. **Send notifications
   again** sends them again.
3. Look in the spam folder — mail from a new domain often lands there for a while.
4. Ask whoever runs the site to check the mail settings.

## 4. Spam

Every form is rate-limited and has a hidden field that catches most bots. Tidewater's demo form also has a CAPTCHA,
whose keys are under **Globals → Integrations**. If spam gets through anyway, a CAPTCHA is the first thing to ask
for.

## 5. How long they are kept

Submissions are deleted on a schedule the site sets, so a contact form does not quietly collect people's details for
years. Tidewater's demo requests are kept for 90 days. Export anything you need to keep before then.

Submissions of a form the site no longer has are deleted too, after the retention that form last had or, if it had
none, 30 days after it was removed.

### Requests about one person

When someone asks what the site holds about them, or asks to be erased, an administrator opens **Forms → Personal
data**, confirms their password and enters the email address. The page counts the matching submissions in every form,
including forms the site no longer has. **Export JSON** or **Export CSV** gives the person their data; **Erase**
deletes those submissions and their uploaded files for good. Both are recorded in the audit log.

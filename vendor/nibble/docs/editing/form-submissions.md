---
id: editing-form-submissions
title: Find and handle form submissions
description: Read, search and export what people sent through the site's forms, deal with spam, retry a failed delivery and find or erase one person's data.
order: 8
---

# Find and handle form submissions

Every demo request Tidewater's site receives is kept, emailed to sales and listed in the Control Plane. This guide
is for whoever answers them.

After reading this guide, you will know:

- Where submissions are, and how to find one.
- How to mark one handled, keep it unread, and leave notes for your team.
- How to export them for a spreadsheet.
- What to do with spam, and with a delivery that failed.
- Where notification emails come from, and what to check when they stop.
- How long submissions are kept.
- How to find or erase everything held about one person.

## 1. Reading submissions

Open **Forms** in the sidebar and choose a form. Each has its own list, newest first. The tabs above it are **All but
spam** and **Spam** (see [Spam](#4-spam)):

![Submissions to the Book a demo form](../../images/cp/form-submissions.png)

Search and **Filters** narrow it; the columns button chooses which fields are shown. Open one to see everything that
was sent, when, and what happened to it — whether its emails went out and whether it reached any other system the
form sends to.

**Uploaded files** — a brief, a logo — are attached to the submission and open from it.

A submission can be deleted from its **…** menu once it has been dealt with.

### Handling

Every submission starts as **New**. Press **Mark handled** on its page, or select several in the list and choose
**Mark handled**, when someone has dealt with it; **Mark not handled** puts it back to New. The **Handling** filter shows only the
New or only the Handled ones, and a handled submission says who handled it and when. Opening a submission marks it
read; **Mark unread** brings it back to the unread count so you remember to return to it.

**Notes** on the submission page are for your team: who wrote each one and when is kept beside it, and visitors never
see them. Handling, unread and notes need permission to edit the form's submissions.

## 2. Exporting

**Export Submissions** downloads the lot as a spreadsheet file (CSV) that Excel or Google Sheets opens — for an event's sign-ups, or a month of
demo requests for someone who does not use the Control Plane. The file has every field of the form in the form's order, plus the date and status, whichever columns the list shows; a search or filter narrows which submissions it holds.

Exports and deletes are recorded in the audit log with who did them, which form and how many submissions.

> [!CAUTION]
> An export is people's names and email addresses on your laptop. Keep it only as long as you need it, and do not
> send it round by email.

## 3. Emails

A form can email people when it is submitted. Tidewater's sends each demo request to `sales@`, and pressing Reply
answers the person who asked. Who receives what is part of the form's setup; the address mail is sent **from** is a
site setting. See [Change the site's settings](site-settings.md).

If emails stop arriving:

1. Check the submission is in the list. If it is, the form is working.
2. Open it: it lists each email with who it went to and whether it was sent, skipped or failed. **Send notifications
   again** sends them again.
3. Look in the spam folder — mail from a new domain often lands there for a while.
4. Ask whoever runs the site to check the mail settings.

### Deliveries to other systems

A form can also pass each submission to another system, such as a customer-records tool. A submission's page lists
these under **Deliveries**: where it went, whether it worked, how many attempts were made and any error. If one
failed, choose **Retry** beside it. Ask whoever runs the site if it keeps failing.

## 4. Spam

Every form blocks too-fast repeat submissions and has an invisible trap that most spam bots fall into. A form can also
ask visitors to prove they are human (a CAPTCHA). If spam gets through anyway, a CAPTCHA is the first thing to ask for.

Submissions caught as spam are kept apart. They do not send emails or deliveries. To check them, open the form and choose the
**Spam** tab, which shows how many there are, as in **Spam (3)**. **All but spam** goes back.

If a real person was caught, open their submission and choose **Not spam**, then confirm. It becomes a normal
submission, and its emails and deliveries are sent then, as they would have been at first. Spam is deleted after a
while, 30 days unless the site says otherwise, so look now and then.

## 5. How long they are kept

Submissions are deleted on a schedule the site sets, so a contact form does not quietly collect people's details for
years. Tidewater's demo requests are kept for 90 days. Export anything you need to keep before then.

Submissions of a form the site no longer has are deleted too, after the retention that form last had or, if it had
none, 30 days after it was removed.

## 6. Find or erase one person's data

When someone asks what the site holds about them, or asks to be erased, an administrator opens **Forms → Personal
data**, confirms their password and enters the email address. The page counts the matching submissions in every form,
including forms the site no longer has. **Export JSON** or **Export CSV** gives the person their data (JSON is for other systems, CSV opens in a spreadsheet); **Erase**
deletes those submissions and their uploaded files for good. Both are recorded in the audit log.

---
id: running-administering
title: Administering from the Control Plane
description: For an administrator without a terminal — what you can do entirely in the Control Plane to keep a site
  healthy, and what to ask a developer for.
order: 10
---

# Administering from the Control Plane

Not everyone who looks after a site has a terminal. At Tidewater, Mina is the marketing lead and the site's
administrator; the developer who deployed it is a contractor she emails twice a year. Almost everything she needs to
keep the site healthy is in the Control Plane. This page is the map: what to do for each job, and where the details
are.

After reading this, you will know which jobs are yours, and which to hand to a developer, and with what words.

## 1. People

Under **Users** you add people, give each the smallest role that lets them work, reset a password, revoke a signed-in
device and remove someone who has left. Under **Roles** you make roles of your own. Keep two administrators, so one
lost phone is not a crisis. Everything is in [Users and roles](users-and-roles.md); when someone cannot sign in, go
straight to [Someone cannot get in](users-and-roles.md#51-someone-cannot-get-in).

## 2. Connected apps and tokens

**Agent access** switches on whether people may connect AI apps such as Claude, decides which parts of the site those
apps may touch, and lists every connected app so you can see what each has done and disconnect it. Approvals let
you make an app ask before it publishes. See [Agent access](agent-access.md). Programs that are not people use API
tokens, under **API tokens**; give each the narrowest scope and revoke ones you no longer use.

## 3. Settings you can change yourself

| Where | What |
|---|---|
| **Site settings → Integrations** | CAPTCHA keys, who mail comes from, analytics IDs, code for the page's head and body |
| **Site settings → SEO** | the title template, and defaults for search results and share cards |
| **Updates** | whether Nibble checks for new releases |
| **Redirects** | where old addresses should go |
| **Webhooks** | telling another application when content changes: [Webhooks](webhooks.md) |

They take effect as soon as they are saved. Secrets that live in the server's environment or credentials, such as the
site's address, the mail login and the backup bucket, are changed by whoever deploys the site; see
[Configuration](configuration.md#6-environment-and-credentials) for what to ask them to set.

## 4. When something looks wrong

Open **Utilities**; [the guide](utilities.md) explains every screen. By symptom:

| What you see | Do this |
|---|---|
| A page still shows old content after you published | **Utilities → Cache**, then **Clear by tag** with the page's `entry:` number, or **Clear all pages**. If a CDN fronts the site, purge it too. |
| Search misses a post that exists | **Utilities → Search**, then **Rebuild indexes** |
| Something that should happen in the background did not (an email, a resized image, a scheduled post) | **Utilities → Health** first; then **Jobs**: failed jobs can be retried once the cause is fixed |
| A scheduled task stopped | **Utilities → Scheduled tasks**: see when it last ran and why it failed, and **Run now** |
| A scheduled post did not go out | **Utilities → Health**: the queue check fails when scheduled publishing has not run for five minutes |
| You want to know who changed or unpublished something | **Utilities → Audit log** |
| You changed the site's structure and want it checked | **Utilities → Schema**; each message is explained in [Check messages](check-messages.md) |
| The site is slow or errors | **Utilities → Health** to see which part is down; give the answer to the developer |

## 5. Backups

**Utilities → Backups** tells you when the database was last copied, and whether a copy also goes offsite. Look at it
once a month: a date from last night and **S3: Configured** is what you want. If it says copies stay on this server
only, ask the developer to set up the offsite bucket; [Backups](backups.md) says what to ask for. A restore is done
by a developer, but knowing it is possible, and from how recent a copy, is your job.

## 6. Moving content

**Utilities → Content** exports the whole site's content as a zip, and imports one with a preview before anything
changes. It is how you move content between a trial site and the real one. See
[Content packages](content-packages.md).

## 7. Updates

**Updates** lists each new release and what changed, and flags any that need action. Taking a release is a developer's
job: it changes the site's code, and runs on their computer, with a snapshot to undo it. When a release matters to you,
send them its entry. See [Upgrading](upgrading.md).

## 8. What to ask a developer for

- A site-wide setting, a secret or a password for a service (mail, uploads, backups): say which, and that it is an
  environment variable or credential.
- A restore from backup: say the date you want back to.
- A new collection, field or page layout: that is the schema and the theme.
- A task that keeps failing, with the message **Scheduled tasks** shows.
- Anything **Utilities → Health** reports as down.
- A person locked out of two-factor with no recovery codes: see
  [Someone cannot get in](users-and-roles.md#51-someone-cannot-get-in); the fix needs a console.

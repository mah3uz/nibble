---
id: running-utilities
title: Utilities
description: The Control Plane's maintenance screens — cache, search, jobs, scheduled tasks, health, content, schema,
  backups and the audit log — what each shows, what its buttons do, and when to reach for it.
order: 11
---

# Utilities

When something about the site is not right, a page looks stale, search misses a post, a task has stopped, the first
place to look is **Utilities**, in the Control Plane's sidebar. Everything here can be done without a terminal, and
where the command line has an equivalent, each section names it.

Opening Utilities needs the `utilities.view` ability. Rebuilding search, exporting content and importing content each
need an ability of their own, and the screens hide a button you may not use.

| Screen | Use it when |
|---|---|
| [Cache](#1-cache) | a public page still shows what you changed |
| [Search](#2-search) | search results are missing or out of date |
| [Jobs](#3-jobs) | something that should happen in the background hasn't |
| [Scheduled tasks](#4-scheduled-tasks) | a task from the schema stopped, or you want it to run now |
| [Health](#5-health) | you want to know if the site's parts are working |
| [Content](#6-content) | moving the site's content to another site |
| [Schema](#7-schema) | you changed blueprints or settings and want them checked |
| [Backups](#8-backups) | you want to know the database is being copied |
| [Audit log](#9-audit-log) | you want to know who changed something |

## 1. Cache

Nibble keeps each public page it has built, so the next visitor gets it straight away. The page cache clears itself
whenever a record a page shows is published or changed, so you rarely need this screen. How it works, and what the
tags are, is in [the page cache and CDNs](deploying.md#6-the-page-cache-and-cdns).

- **Clear all pages** empties the cache store. The next visit to each page builds it again, so the site is slower for a
  few minutes. The store is the site's general cache, so anything else kept there goes too.
- **Clear by tag** clears only the pages that show certain records. Give it tags such as `entry:12`,
  `collection:posts`, `term:5`, `taxonomy:topics`, `global:company` or `navigation:main`, separated by commas or
  spaces. A page that still looks wrong after a publish is the reason to use it.

If a page is stale because of a CDN in front of the site, clearing here changes nothing: purge the CDN as well.

Command line: none; Utilities is the way.

## 2. Search

Lists each search index, the collections and taxonomies it covers and the fields it searches, with a count of
documents in the indexes beside the number of live entries they should cover. If the two numbers are far apart,
or results lag behind what editors see, rebuild.

**Rebuild indexes** (needs `search.rebuild`) empties every index and fills it again from the live content, files
included. It is safe at any time; search returns fewer results until it finishes, which on a large site can take a
while.

Command line: `bin/rails nibble:reindex`.

## 3. Jobs

Nibble does its slow work in the background: sending webhooks, resizing images, updating search, publishing on
schedule. **Jobs** shows that queue.

- **Queues.** The five Nibble uses (`events`, `deliveries`, `media`, `search`, `maintenance`), how much is waiting in
  each and how long the oldest has waited. Work that waits a long time means no worker is running.
- **In progress** and **Scheduled**: what is running now, and what is waiting for its time.
- **Failed jobs.** Each shows the job, the error and where it failed. **Retry** queues it again, which is right
  once you have fixed what made it fail; **Discard** deletes it, which is right when it no longer matters. The latest 50
  are shown.
- **Recurring.** The jobs that run on a clock, and when each last ran:

| Job | When |
|---|---|
| `run_publishing_schedule` | every minute: publishes and unpublishes what is scheduled |
| `daily_release_check` | 4am: looks for a newer Nibble release |
| `nightly_database_snapshot` | 3am: the [backup](backups.md) |
| `nightly_trash_purge` | 3:15am: deletes what has been in the trash long enough |
| `nightly_submission_purge` | 3:30am: deletes form submissions past their retention |
| `nightly_webhook_delivery_purge` | 3:45am: deletes [webhook](webhooks.md) deliveries older than 30 days |
| `clear_solid_queue_finished_jobs` | hourly: clears finished jobs |

If a Nibble job is missing from this list, `nibble:check` warns that its work never runs; it was removed from
`config/recurring.yml`.

The screen says the job queue is unavailable where it is not running, as in development unless you start it.
Command line: none; `bin/kamal logs` shows what the worker prints.

## 4. Scheduled tasks

Tasks are jobs a developer wrote in the schema, such as "fetch the weather every hour" (see
[Scheduled tasks](../modelling/scheduled-tasks.md)). The screen lists each with its schedule, next run and last
result.

- **Run now** queues one run straight away. It says so if the task was started a moment ago, or declines if the
  previous run is still going.
- **Pause** stops it running on its schedule. **Resume** starts it again from its next slot; the runs missed while
  it was paused are not made up.
- **History** shows the runs of the last 30 days (up to 100), with their messages.

A task that starts failing tells the site's administrators once, and shows "failing since" here until it succeeds.

Command line: none. The task's definition is in `site/schema/tasks/`.

## 5. Health

**Health** checks the site's four parts now and says **ok**, **degraded** (something needs attention) or **down**
(something is broken).

| Check | Fails or warns when |
|---|---|
| Database | it cannot be reached, or the release has migrations that have not run (run `bin/rails db:prepare`, or deploy) |
| Queue | no worker has checked in; scheduled publishing has not run in five minutes (both fail); work has waited over five minutes, or there are failed jobs (both warn) |
| Storage | the upload storage, local disk or S3, does not answer |
| SSR | the server-side rendering process does not answer on its port |

Where a check does not apply (no job queue in development, rendering off) it says **skip**. Beside the checks it lists
what the site runs on (Ruby, Rails, the environment) and its size: entries, terms, items in the trash and events
waiting to be processed. A growing count of waiting events with a healthy queue is worth a report.

Command line: `/up` answers 200 when the application has started, and is what Kamal's proxy watches. It does not run
these checks.

## 6. Content

Exports every entry, term, global, menu and redirect, drafts included, as a zip you can keep or import into another
site, and imports one: it first shows what would be created, updated or skipped, and changes nothing until you
confirm. Exporting needs `content.export`, importing `content.import`, and opening the screen asks for your password
again. The import's own options and what a
package holds are in [Content packages](content-packages.md).

Command line: `bin/rails nibble:content:export DIR` and `nibble:content:import DIR`.

## 7. Schema

Shows the schema the site is running (its digest, the theme, and the collections, taxonomies, globals and menus it
defines) and the findings of `nibble:check`: each with the file it concerns, what is wrong and whether it is an error
or a warning. Errors stop a deploy. Check it after changing a blueprint, or after an upgrade. Every message is explained
in [Check messages](check-messages.md).

Command line: `bin/rails nibble:check`.

## 8. Backups

Shows the most recent copy of the database kept on this server (when it was taken, its size and its file name) and
whether an offsite copy is on. The nightly job keeps the last seven days locally; with `DB_SNAPSHOT_BUCKET` set, it
uploads each copy to S3 too. "Backups stay on this server only" means the bucket is unset, and a lost server loses the
backups with it.

The screen only reports. It cannot take or restore a copy; how to is in [Backups](backups.md).

## 9. Audit log

The latest changes first, 25 at a time, with older ones loading as you scroll. Each row has the action, who did it,
when, from which address, what it was done to and which fields changed.

It records every change to content (`record.created`, `record.published`, `record.trashed`, and so on), workflow
changes, and what concerns access: signing in and out, failed sign-ins, lockouts (`auth.locked_out`), two-factor and
passkeys being added or removed, and role changes. A change made by a connected app is recorded as the person it acts
for, with the app's grant. It is how you answer "who unpublished the pricing page, and when" and "was that sign-in me".

Command line: none.

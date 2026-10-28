---
id: modelling-scheduled-tasks
title: Scheduled tasks
description: Keep a global's figures fresh from an API, import a feed into a collection, call a URL, or run your own
  Ruby, on a schedule declared in schema.
order: 8
---

# Scheduled tasks

Tidewater's home page shows how many teams use the product and how many shipments it tracked this month. Those
figures live in the company's own API, and the site should keep up with them without anyone copying numbers across.
Its careers page should list the jobs open in the hiring system, and nothing else. A scheduled task does each of these.

After reading this guide, you will know:

- How to declare a task and write its schedule.
- How to fetch figures from an API into a global.
- How to import a feed into a collection, and withdraw what the feed drops.
- How to call a URL on a schedule.
- How to run your own Ruby on a schedule.
- What happens when a run fails, overlaps another or is missed.

## 1. Declaring a task

Each task is one file in `site/schema/tasks/`. Its file name is its handle:

```yaml
# site/schema/tasks/stats.yml
title: Home page figures
description: Customer and shipment counts for the home page.
schedule: every 2 hours
fetch:
  use: tidewater
  path: /stats
  into:
    global: stats
    map:
      teams: "{response.data.teams}"
      shipments: "{response.data.shipments_this_month}"
```

`title` and `schedule` are required, and a task does exactly one thing: `fetch`, `request` or `handler`.

### 1.1 Schedules

A schedule is written as Rails' recurring jobs write theirs:

| Schedule | Runs |
|---|---|
| `every 2 hours` | at midnight, 2am, 4am… |
| `every hour` | on the hour |
| `at 5am every day` | once a day, at five |
| `every monday at 9am` | once a week |
| `*/15 * * * *` | a cron line: every quarter of an hour |
| `0 6 * * * Europe/Berlin` | a cron line in a time zone of its own |

Schedules follow the site's time zone, `config.time_zone` in `config/application.rb`, unless the line names one.
Tasks are checked once a minute, so nothing runs more often than that, and `nibble:check` refuses a schedule it
cannot read.

## 2. Fetching figures into a global

A `fetch` calls an API and saves what it answers. Name an [API connection](forms.md#51-api-connections) with `use:`
and a `path`, or give a whole `url:`:

```yaml
# site/schema/apis/tidewater.yml
base_url: https://api.tidewater.example/v2
headers:
  Authorization: "Bearer {secret.tidewater_token}"
```

```yaml
# config/nibble.yml
outbound:
  allowed_hosts: [api.tidewater.example]
  secrets: [tidewater_token]
```

`method` is `get` unless you say otherwise, and `headers` and `body` may use `{secret.x}` and `{config.x}`, as a form's
API delivery does. Every call goes through the same checks as the rest of Nibble's: only allowed hosts, never a
private address, and each request is logged.

`into.global` names the global, `into.locale` its locale (the site's default when left out), and `into.map` says which
field takes which part of the answer. `{response.data.teams}` reads `data`, then `teams`; a number reads from a list,
as in `{response.items.0.price}`. A value may also mix text and paths: `"{response.count} teams"`.

Mapped values replace the stored ones, and the rest of the global is left alone. When the call fails — the API
answers with an error, takes too long, isn't allowed, or sends something that isn't JSON — the run fails and the
global keeps the figures it had. A path the answer doesn't have leaves that one field as it is, and the run says
which. Nothing is saved when the figures haven't changed, so the global's history shows only real changes.

> [!NOTE]
> An answer is only ever read for `{response.…}`. Text in it that looks like `{secret.…}` is saved as it is, so a
> remote system can't pull one of your secrets into the site.

## 3. Importing a feed into a collection

Tidewater's open roles come from its hiring system, one entry per job:

```yaml
# site/schema/tasks/jobs.yml
title: Open roles
schedule: every hour
fetch:
  url: https://hiring.example/api/jobs?status=open
  into:
    collection: jobs
    items: "{response.jobs}"
    key: ref
    unpublish_missing: true
    map:
      title: "{item.title}"
      ref: "{item.id}"
      location: "{item.location.city}"
```

`items` names the list in the answer, and inside `map`, `{item.…}` reads one entry of it. `key` names the mapped
field — or `slug` — that identifies an item from one run to the next. `blueprint` picks a blueprint other than the
collection's first. Entries are written in the site's default locale.

An item seen for the first time becomes a new, published entry. Next time, the same key updates that entry, and an
item whose values haven't changed is left alone, so running the same feed twice changes nothing the second time. An
item without a key value is skipped. A collection that uses the review workflow can't be imported into, because
nothing would approve what the task publishes.

**A task only ever changes entries it created itself.** It remembers each entry it made, by key, and works only with
those. An entry someone made in the Control Plane is never updated or unpublished by a task, even when its value for
the key matches an item in the feed.

`unpublish_missing: true` unpublishes the task's entries whose key the feed no longer lists, and republishes one when
it comes back. Two more rules keep it safe:

- An empty list unpublishes nothing. A feed that suddenly lists nothing is far likelier to be a fault at the other end
  than every job filled at once.
- An entry someone unpublished by hand stays unpublished. Only what the task unpublished does it republish.

An entry with unpublished edits is left alone until the editor publishes or discards them: the task neither updates
it nor unpublishes it, so a feed refreshing never puts someone's unfinished work live. The run counts it as skipped,
and says why.

Imported fields are the feed's: a change made to one in the Control Plane is replaced on the next run that brings a
different value.

## 4. Calling a URL

A `request` calls a URL and succeeds when the answer is a `2xx`:

```yaml
# site/schema/tasks/warm-cache.yml
title: Warm the status page
schedule: at 5am every day
request:
  url: https://status.tidewater.example/hooks/refresh
  method: post
  body:
    source: nibble
    token: "{secret.status_token}"
```

`method` is `post` unless you say otherwise. `use:` and `path:` work as they do for `fetch`.

## 5. Running your own Ruby

For anything YAML cannot express, a task names a `handler` registered in Ruby:

```yaml
# site/schema/tasks/carriers.yml
title: Carrier count
schedule: at 6am every day
handler: carrier_count
```

```ruby
# config/initializers/tasks.rb
Nibble::Tasks.register_handler("carrier_count", lambda do |task|
  carriers = task.connection(:tidewater).get("/carriers").json.fetch("carriers")
  task.update_global(:stats, { carriers: carriers.count { |carrier| carrier["active"] } })
  { carriers: carriers.size }
end)
```

The handler is given the task's context; [Ruby hooks and events](../extending/hooks.md#6-task-handlers) lists what it
offers. A hash the handler returns is kept with the run, and an error it raises fails the run with its message.
`nibble:check` refuses a task whose handler isn't registered.

## 6. When runs fail, overlap or are missed

Each run is recorded with when it was due, when it started and finished, and how it went: succeeded, failed or
skipped. **Utilities → Scheduled tasks** lists them, and runs a task, pauses it or resumes it on request. Runs are kept
for 30 days.

- **A slot runs once**, even with several job workers.
- **A run still going is never overlapped.** The next slot is recorded as skipped. A run unfinished after an hour is
  taken to have been lost with its worker, and the next slot runs.
- **Missed slots aren't made up.** After the site has been down for a few hours, the task runs once, for the latest
  slot. A new task waits for its first slot, and a resumed one for its next.
- **Failures are announced once.** When a task that was succeeding fails, administrators are notified. They aren't
  told again until it has succeeded and then failed again.

Tasks are run by the job that publishes scheduled entries, on the `maintenance` queue, so production needs nothing
more. In development, where no scheduler runs, **Run now** still works.

## 7. Every key

| Key | Notes |
|---|---|
| `title`, `schedule` | **required** |
| `description` | shown with the task |
| `fetch` | `{ use and path, or url; method; headers; body; into }` |
| `fetch.into` (global) | `{ global, locale, map }` |
| `fetch.into` (collection) | `{ collection, blueprint, items, key, map, unpublish_missing }` |
| `request` | `{ use and path, or url; method; headers; body }` |
| `handler` | a handler registered with `Nibble::Tasks.register_handler` |

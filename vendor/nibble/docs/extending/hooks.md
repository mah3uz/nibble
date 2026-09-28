---
id: extending-hooks
title: Ruby hooks and events
description: Your own Ruby beside Nibble's — initializers, load hooks, event subscribers, form handlers, webhooks and
  gems.
order: 1
---

# Ruby hooks and events

Say you want two things Nibble does not do: tell the team's chat channel when a blog post goes live, and start a
trial account when someone books a demo. Both are a few lines of Ruby in the right place.

After reading this guide, you will know:

- Where your own Ruby lives, and when it runs.
- How to add behaviour to a record without reopening its class.
- How to react to content changing.
- How to give a form a handler.
- How to tell another application with a webhook.
- How to add an analytics tool Nibble doesn't know.

## 1. Your own code

A site's `app/` loads beside Nibble's, exactly where a Rails application keeps it: `app/models`, `app/jobs`,
`app/mailers`, `app/controllers`. Nothing of Nibble's is in there, so nothing you add is ever in the way of an
upgrade.

Gems of your own go in `Gemfile`, below the line that reads Nibble's:

```ruby
# Gemfile
eval_gemfile "vendor/nibble/Gemfile"

gem "slack-notifier"
```

## 2. Initializers

`config/initializers/*.rb` run at boot. They are where the rest of this guide's code
goes.

```ruby
# config/initializers/slack.rb
Rails.application.config.after_initialize do
  TidewaterSlack.webhook_url = ENV["SLACK_WEBHOOK_URL"]
end
```

## 3. Load hooks

Add behaviour to Nibble's records as their classes load, rather than reopening them:

```ruby
# config/initializers/entries.rb
ActiveSupport.on_load(:nibble_entry) do
  def reading_minutes = values["body"].to_s.split.size / 230
end
```

`:nibble_entry`, `:nibble_term` and `:nibble_asset` are available.

> [!WARNING]
> Reopening a Nibble class — `class Nibble::Records::Entry` in your own file — works today and breaks quietly
> later, when the class changes under you. Load hooks are what exist to prevent that.

## 4. Events

Nibble publishes what happens to content, and a site can subscribe:

```ruby
# config/initializers/announce.rb
Nibble::Events.subscribe("record.published", async: true) do |name, payload|
  next unless payload["collection"] == "posts"

  AnnouncePostJob.perform_later(payload["id"])
end
```

| Event | When |
|---|---|
| `record.created`, `record.saved` | an entry, term, global or menu is created or saved |
| `record.published`, `record.scheduled`, `record.unpublished` | publishing |
| `record.trashed`, `record.restored`, `record.moved` | the trash, and the tree |
| `workflow.transitioned` | review moved an entry on |
| `form.submitted` | a form was submitted |

A pattern ending in `.*` — `record.*` — matches a family. The payload carries the record's `type`, `id` and `locale`,
its `collection` or `taxonomy`, and for entries its `uri`, `previous_uri` and whether it `was_live`, plus the `actor`
who did it.

> [!IMPORTANT]
> Pass `async: true`. An asynchronous subscriber runs after the change is committed, from an outbox: a slow or
> failing subscriber cannot hold up or undo the publish, and nothing is lost if the process dies in between. A
> synchronous one runs inside the publish itself, and an error in it stops the publish.

Keep subscribers short, and hand real work to a job, as above.

## 5. Form handlers

A form can name a handler that Ruby provides, for what a template cannot express:

```ruby
# config/initializers/forms.rb
Nibble::Forms.register_handler("start_trial", lambda do |form:, data:, submission:|
  TrialAccount.create_from_demo_request!(email: data["email"], team_size: data["team_size"])
end)
```

```yaml
# site/schema/forms/demo.yml
handler: start_trial
```

The handler runs in a background job after the submission is stored, so a slow handler never keeps the visitor
waiting. `nibble:check` refuses a form whose handler is not registered.

## 6. Webhooks

When the thing to tell is another application, you may not need Ruby at all. **Webhooks**, in the Control Plane,
posts a signed payload to a URL on the events you choose — the same events as above — and shows each delivery and
its retries.

Each delivery is a JSON `POST` with an `X-Nibble-Signature` header, `t=<timestamp>,v1=<signature>`, where the
signature is the HMAC-SHA256 of `<timestamp>.<body>` with the webhook's secret. Check it before trusting the body.

You could, for example, rebuild the product's in-app "What's new" panel from a webhook on `record.published`.

> [!NOTE]
> Webhook URLs are subject to `outbound.allowed_hosts` in [configuration](../running/configuration.md#4-every-key),
> like every call Nibble makes.

## 7. An analytics tool of your own

The [Analytics tab](../editing/analytics.md) lists the tools Nibble knows. To add one, give it a set in the
Integrations global and a renderer in Ruby that writes its tags.

Copy `vendor/nibble/core_schema/globals/integrations.yml` to `site/schema/globals/integrations.yml`, and add a set
under the `analytics` field's `other` group:

```yaml
counter:
  display: Counter
  icon: chart
  badge: No cookies
  instructions: Tidewater's own visit counter.
  fields:
    - handle: site_code
      field: { type: text, display: Site code, required: true, validate: ["regex:/\\A[a-z0-9]+\\z/"] }
```

Then register a renderer under the set's handle:

```ruby
# config/initializers/analytics.rb
Nibble::Analytics.register("counter") do |card, page|
  code = card["site_code"].to_s
  next unless code.match?(/\A[a-z0-9]+\z/)

  page.add(:head, %(<script defer src="https://counter.tidewater.example/count.js" data-code="#{ERB::Util.html_escape(code)}"></script>))
end
```

The block receives the card's values and the page. `page.add` takes the place, `:head`, `:body_start` or
`:body_end`, and the HTML; pass `once: "<key>"` for a loader several cards share, and it is written once. A paused
card never reaches the block.

> [!WARNING]
> The renderer writes HTML into every live page. Check each value against the shape it should have, as above, and
> escape it, even though the blueprint validates it too: a value stored before a rule existed never passed it.

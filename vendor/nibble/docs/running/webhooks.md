---
id: running-webhooks
title: Webhooks
description: Tell another application when content changes or a form is submitted — set one up, what it sends, how it
  is signed, how failures are retried, and how to read its deliveries.
order: 12
---

# Webhooks

Tidewater's marketing team keeps a "What's new" panel in the product itself, and it should change the moment a
release note is published. Rather than have the product poll the site, the site tells it. That is a webhook: when
something you chose happens, Nibble sends a signed `POST` to a URL you gave it, and keeps a record of how that went.

After reading this guide, you will be able to set a webhook up, check that what arrives is genuine, and know what
Nibble does when the receiver is down.

## 1. Setting one up

Open **Webhooks**, under **Tools**, and choose **Create webhook**. You need the `webhooks.manage` ability, which
administrators have and other [roles](users-and-roles.md#3-roles-of-your-own) can be given.

| Field | What it does |
|---|---|
| **Name** | what you call it in the list and in notifications |
| **URL** | where deliveries go; an absolute `http` or `https` address |
| **Events** | which events to send; at least one |
| **Collections** | for content events, only changes in these collections; leave empty for all of them |
| **Send deliveries** | the on/off switch |

On creating it, Nibble makes a **signing secret** (it starts `whsec_`) and shows it on the page: reveal it, copy it,
and give it to whoever runs the receiver. **New secret** replaces it at once, so update the receiver straight away;
deliveries signed with the old one will be refused.

**Send test** posts a `webhook.test` event to the URL and tells you at once whether it was delivered, with the HTTP
status, or why not. A test is tried once, is never retried, and does not count towards the failures in
[section 5](#5-when-the-receiver-is-down).

> [!NOTE]
> Nibble only calls hosts named in `outbound.allowed_hosts`, as it does for every call it makes. Add the receiver's
> host there before you create the webhook. See [Configuration](configuration.md#4-every-key).

## 2. Events

| Event | Sent when |
|---|---|
| `record.created` | an entry, term or other record is created |
| `record.saved` | one is saved |
| `record.published` | one is published |
| `record.scheduled` | one is scheduled for later |
| `record.unpublished` | one is taken down |
| `record.trashed` | one is moved to the trash |
| `record.restored` | one is brought back from the trash |
| `record.moved` | one is moved in its tree |
| `record.*` | any of the above |
| `workflow.transitioned` | a collection's workflow status changes |
| `form.submitted` | someone submits a form |

Saving a draft sends `record.saved` too, with `"draft": true` in `data`; a receiver that only wants live content
should ignore those. Content brought in by an import sends nothing unless it was run with `--webhooks`.

## 3. What a delivery looks like

Every delivery is a JSON `POST` with these headers:

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |
| `X-Nibble-Event` | the event name, such as `record.published` |
| `X-Nibble-Delivery` | the delivery's number, the same on each retry of it |
| `X-Nibble-Signature` | `t=<timestamp>,v1=<signature>`, explained below |

and this body:

```json
{
  "id": "evt_1042",
  "event": "record.published",
  "created_at": "2026-10-30T01:12:09Z",
  "data": {
    "type": "entry",
    "id": 87,
    "locale": "en",
    "collection": "posts",
    "actor": { "type": "user", "id": 3 }
  }
}
```

`id` names the event, and stays the same when a delivery is retried or resent, so a receiver can use it to ignore one
it has already handled. `data` says what changed and who did it, not the content itself: for a record it is the
`type` (`entry`, `term`, `global` or `navigation`), its `id` and `locale`, its `collection`, `taxonomy` or
`handle`, and the `actor` who made the change (absent for changes the system makes, with the app's `grant_id` when a
connected app made it); some events add more, such as the `changes` of a draft save. For `form.submitted` it is the
`form` handle and the submission's `id`. Fetch the record from the [content API](../theming/content-api.md) if you
need its fields. The sender's IP address is never included.

## 4. Checking the signature

Anyone who learns the URL can post to it, so check the signature before trusting a body.

1. Read the `X-Nibble-Signature` header and split it into `t` (a Unix timestamp) and `v1`.
2. Compute the HMAC-SHA256, as hex, of the timestamp, a full stop and the **raw** request body, with the signing
   secret as the key.
3. Compare it with `v1` in constant time. Reject the request if they differ, or if the timestamp is further from now
   than you are willing to accept (five minutes is usual), which stops a captured request being replayed later.

```ruby
expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
ActiveSupport::SecurityUtils.secure_compare(expected, v1)
```

Answer with any `2xx` status as soon as you have the body safely stored; do the work afterwards. A delivery waits ten
seconds for an answer.

## 5. When the receiver is down

Anything other than a `2xx` answer, a refused connection or a timeout is a failed attempt. Nibble tries again after a
growing wait, eight attempts in all:

| After attempt | Waits |
|---|---|
| 1 | 1 minute |
| 2 | 5 minutes |
| 3 | 30 minutes |
| 4 | 2 hours |
| 5 | 5 hours |
| 6 | 10 hours |
| 7 | 24 hours |
| 8 | none: the delivery is marked failed |

Every failed attempt, retries included, adds to the webhook's count of failures in a row, and any success sets it back
to nothing. At **20 in a row** Nibble switches the webhook off, because a receiver that has been gone for a while is
better left alone than hammered. When that happens:

- the deliveries still waiting to be retried are marked failed, and no new events are queued for it;
- every person who can manage webhooks gets a notification, and the webhook shows why it stopped;
- the dashboard's **Failed deliveries** widget lists the failures.

Fix the receiver, then open the webhook and choose **Turn back on**; that clears the count.

## 6. Reading the deliveries

Opening a webhook lists its fifty most recent deliveries, newest first, each with its event, status (pending,
delivered or failed), the number of attempts and the HTTP status or error of the last one. Expanding one shows the
request that was sent and the answer that came back, and how long it took, which is usually enough to see why the
receiver refused it.

**Resend** queues a delivery again, as a new delivery with the same event `id`. Use it once the receiver is fixed to
catch up on events it missed. Deliveries are kept for 30 days, then deleted by a nightly job.

The list at **Webhooks** shows each webhook with its events, whether it is on, and how its last delivery went.

## 7. The same thing in code

A webhook is for another application. To react inside the site, subscribe to the same events in Ruby: see
[Extending with hooks](../extending/hooks.md#7-webhooks).

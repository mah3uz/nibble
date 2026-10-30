---
id: extending-management-api
title: The management API and MCP
description: How apps, scripts and AI agents change a site's content as a person — the endpoints, signing in,
  operations, errors, and the rules that keep them safe.
order: 4
---

# The management API and MCP

The [content API](content-api.md) serves published content to other websites. This API is the other
half: it changes content, always as a person, through the same checks as the Control Plane. The `nibble` command and
AI apps use it; so can anything you build.

After reading this guide, you will know:

- The two ways in: HTTP and MCP.
- How an app signs in.
- The operations, and the rules every change follows.
- What errors look like, and how to act on them.
- How a change waits for a person, and how to follow it.

Agent access must be [turned on](../running/agent-access.md); until then these endpoints answer 404.

## 1. Two ways in

| Endpoint | For |
|---|---|
| `POST /mcp` | MCP clients — Claude, ChatGPT, Codex, Cursor. Stateless JSON-RPC over HTTP; each operation is a tool |
| `GET /api/v1/operations` | the operations this token may use, with their arguments as JSON Schema |
| `GET /api/v1/operations/<operation>` | an operation that only reads; arguments in the query string |
| `POST /api/v1/operations/<operation>` | any operation; arguments as a JSON body |
| `PUT /api/v1/uploads` | a file's bytes, held for `upload_asset` |

Both are built from one list of operations, so they never disagree. Answers are never cached. Every `/api/v1/operations` answer,
refusals included, carries `Nibble-Api-Version`: the management API's contract number. It changes only when a client
written for the old number would misread the new answers; a new operation or argument doesn't change it, because
clients read those from the list. The `nibble` CLI checks it on every answer and says whether the CLI or the site needs
upgrading.

## 2. Signing in

The site is its own OAuth authorization server, for public clients only:

- **Discovery:** `/.well-known/oauth-protected-resource/mcp` (or `/api/v1`) names the site as the authorization
  server; `/.well-known/oauth-authorization-server` describes it.
- **Authorization code with PKCE (S256)**, the only flow a browser takes. Loopback redirects may use any port.
- **Clients** identify themselves with a client metadata document (an `https` URL as `client_id`), register
  dynamically, or — the `nibble` command — are built in.
- **Tokens:** an access token lasts an hour; a refresh token rotates on every use, and reusing an old one disconnects
  the app. Tokens are bound to the endpoint they were issued for: an MCP token doesn't open the operations endpoints.
- **Device code**, only if the site allows it.

Send the token in the `Authorization` header. A token in a URL is refused; the one address that carries its own
permission is `create_upload`'s, and it can only send files.

## 3. Operations

| Group | Operations |
|---|---|
| Site | `whoami`, `describe_site`, `describe_schema`, `get_guide`, `get_approval` |
| Entries | `list_entries`, `get_entry`, `create_entry`, `update_entry`, `transition_entry`, `list_revisions` |
| Terms | `list_terms`, `get_term`, `create_term`, `update_term`, `transition_term` |
| Globals and navigation | `get_global`, `update_global`, `get_navigation`, `update_navigation` |
| Assets | `list_assets`, `get_asset`, `create_upload`, `upload_asset`, `update_asset`, `transition_asset` |
| Forms | `list_form_submissions` |

`list_form_submissions` gives a form's submissions, newest first and spam left out. `since` (an ISO 8601 date or
date-time) keeps those made at or after it, and `q` those whose values contain the text, ignoring case, as the
Control Plane's submissions search finds them: values in encrypted fields aren't searched.

A token sees only the operations it may use. There is no search operation: search belongs to a theme's
[search page](../theming/queries.md#7-search).

`GET /api/v1/operations` also lists, under `unavailable`, the operations this token can't use and what each needs, in
the words of the Agent access page, so an app can tell its person what to change:

```json
{ "data": [ … ],
  "unavailable": [ { "name": "upload_asset", "title": "Upload an asset", "needs": "Assets: Write" } ],
  "meta": { … } }
```

The MCP tool list has only the tools the connection can call.

### Sending files

`upload_asset` takes the file in exactly one of three ways:

- **`upload`**: the id of a file sent to `PUT /api/v1/uploads`. The way to send a file on disk.
- **`url`**: an `http` or `https` address the site fetches, with the checks every outbound request has:
  [`outbound.allowed_hosts`](../running/configuration.md#4-every-key), no private or reserved addresses, and the
  site's upload size limit. `filename` names the file when the address doesn't.
- **`content_base64`** with `filename`: the file inside the request. Only for small files: base64 is a third larger,
  and a request waiting for approval holds the whole file.

Send a file's bytes as the body of `PUT /api/v1/uploads?filename=<name>`, with `Content-Length` and the token in
`Authorization`:

```sh
curl -T photo.jpg -H "Authorization: Bearer $TOKEN" "https://example.com/api/v1/uploads?filename=photo.jpg"
```

```json
{ "data": { "upload": "eyJfcmFpbHMi…", "filename": "photo.jpg", "size": 612034, "expires_at": "2026-10-30T08:10:24Z" },
  "meta": { "site": "https://example.com", "api_version": 2 } }
```

The type and size are checked before anything is kept: an unaccepted type is `415 unsupported_type`, a file over
the limit `413 too_large`, and a request without `Content-Length` `411 length_required`. A sent file has no address
and is no asset yet. Only the connection that sent it can pass its `upload` to `upload_asset`, once, within a day;
the nightly clean-up deletes it after that, unless an approval is still waiting on it.

When `upload_asset` waits for approval, a `url` is fetched and `content_base64` decoded once, and the approval holds
the file as an upload: the person approves the file that will be made, and nothing is fetched again.

An MCP client never shows its token to the agent, so `create_upload` (with `filename`) answers with a `url` that
carries its own permission for 15 minutes, with `method`, `max_bytes`, `accepted_types` and `expires_in`. PUT the
file there with no `Authorization` header: `curl -T photo.jpg "<url>"`.

## 4. Rules every change follows

- **Values follow `describe_schema`.** Unknown fields and arguments are refused with the names that would work.
- **Rich text is Markdown**, at any depth: a `rich_text` field in a replicator set or a grid row, however deeply
  nested, is written and read the same way as one at the top. Images are `![alt](asset:ID)`; links may be web,
  email, phone or site paths, or `global:<set>.<field>` to follow a
  [global field that holds an address](../modelling/globals-and-navigation.md#12-linking-to-a-global-from-rich-text),
  such as `[Apply](global:site.apply_url)`. Content Markdown can't hold comes back as editor JSON, and nodes sent as
  nodes are kept as they are.
- **`describe_schema` lists every set.** A replicator's `items` is a `oneOf` with one schema per set: `type` as a
  `const` (the set's handle) beside the set's fields. A grid's `items` lists its fields. Three levels of nesting are
  described; deeper ones are plain objects.
- **`describe_schema` describes a menu's items.** For a navigation menu, `tree` is the JSON Schema of its items: `kind`,
  the link's `type` and its target (`id`, `url` or `ref`), `title`, `new_tab`, `hidden`, `fields`, `query`,
  `show_from`, `show_until` and `children`. `fields` lists the menu's `item_fields`, and `kinds` lists each custom
  kind's fields. `describe_site` gives the same `tree` and `kinds` for every menu it lists.
- **`describe_schema` carries each field's rules**: `maxLength` from `character_limit`, `format` (`email`, `uri`,
  `date` or `date-time`), `minimum`, `maximum` and `multipleOf` for integers, and `readOnly`. A choice's values are
  its `enum`, and its labels, when they differ, are listed in its `description`. The `description` also says when a
  field only applies ("Only when hero_kind is video") or is read-only on a condition; a field that only applies on a
  condition is never in a row's `required`.
- **Read-only fields are kept.** A value sent for a read-only field is ignored and the rest of the change is saved.
  `create_entry`, `update_entry`, `create_term`, `update_term`, `update_global` and `update_asset` answer with an
  `ignored` list of the fields whose value was kept, as paths such as `code` or `rows.0.checksum`; it is left out
  when nothing was ignored. Rows in grids and replicators keep their read-only values by `id`, so send each row's
  `id` back as `get_entry` gave it.
- **`lock_version` is required** to change something. If someone saved it since you read it, the answer is
  `lock_conflict` with the current `lock_version`, and nothing is overwritten.
- **`dry_run: true`** checks a change completely and saves nothing. The preview has a `warnings` list for what is
  valid but probably a mistake: a replicator row whose `type` isn't one of its sets, or a rich text image
  `asset:ID` that doesn't exist.
- **`preview_url`** comes back from `create_entry` and `update_entry`: the Control Plane preview of the entry's
  draft, for the person signed in there.
- **`idempotency_key`** makes a retry safe: the same key returns the first answer instead of repeating the change.
- **Entries change as drafts.** Publishing is a separate operation.
- **Consequential changes wait for a person** when an app makes them, unless the person let it make them without
  asking. See [Approvals](#6-approvals).
- **Nothing is deleted.** Trashed records can be restored.

## 5. Errors

HTTP answers are [problem documents](https://www.rfc-editor.org/rfc/rfc9457); MCP tool results set `isError`. Both
carry the same fields:

```json
{ "code": "lock_conflict", "message": "someone saved this after you read it",
  "hint": "Read it again, reapply your change to the current data, and send the new lock_version.",
  "details": { "lock_version": 7 } }
```

`code` is stable; `hint` says what to do next.

Calling an operation the connection can't use answers `forbidden` (HTTP 403), naming what it needs:

```json
{ "code": "forbidden", "message": "this connection can't upload an asset: it needs Assets: Write",
  "hint": "Change this connection's access under Account → Connected apps, or sign in again.",
  "details": { "needs": "Assets: Write" } }
```

On HTTP the message is the problem document's `detail`. What a connection needs is the smallest of its person's
roles, the access chosen for it and the site's Agent access settings; see
[Agent access](../running/agent-access.md#6-changing-what-an-app-may-do).

## 6. Approvals

Publishing, unpublishing, trashing, and changes that are live at once — terms, globals, navigation, assets — wait for
the person an app acts for, unless they connected it to make changes without asking. A script token never waits.

The first answer is `approval_required` (HTTP 409):

```json
{ "code": "approval_required", "message": "Ada has to approve this before it happens",
  "details": { "approval": "appr_…", "approval_url": "https://example.com/cp/approvals/appr_…",
               "expires_at": "2026-10-30T09:00:00Z" } }
```

Show the person `approval_url`. There is nothing more to send: when they approve, Nibble makes the change, checking
every permission again first. `get_approval` with the `approval` id says how it went:

```json
{ "approval": "appr_…", "status": "done", "operation": "transition_entry",
  "result": { "id": 42, "status": "published", "…": "…" }, "error": null, "expires_at": "2026-10-30T09:00:00Z" }
```

`status` is `pending`, `approved` (being made), `done` with the operation's usual answer in `result`, `failed` with
the error in `error`, `denied` or `expired`. A change interrupted while being made shows as `failed` with the code
`interrupted` after ten minutes: it may not have been made, so check the record before asking again. An app sees only
its own approvals.

Sending the same request again while it waits answers `approval_required` with the same id; it never asks twice.
Sending it with its `approval` id, or with the `idempotency_key` it was first sent with, answers from that approval:
the stored result once it is `done`, the stored error once it has `failed`, and otherwise:

| Code | Means |
|---|---|
| `approval_required` | the request is still waiting (sent with its `idempotency_key`) |
| `approval_pending` | the `approval` sent hasn't been decided yet |
| `approval_denied` | the person declined it; nothing changed |
| `approval_expired` | nobody decided in time; send the request without `approval` or its key to ask again |
| `approval_mismatch` | the `approval` sent belongs to another connection or a different request |

All are HTTP 409. Once an approval is finished, the same request sent without its id or key is a new request: it
asks again.

## 7. Telling agents about the site

Agents get a guide to the site — how to work, its content model — as the MCP server's instructions, as a skill
through MCP's Skills extension, and from `get_guide`. It's written from the schema and from the site's own notes in
`site/agents/*.md`, and never from content, so nothing a visitor writes can become an instruction. Put the editorial
rules you'd tell a new writer in `site/agents/voice.md`.

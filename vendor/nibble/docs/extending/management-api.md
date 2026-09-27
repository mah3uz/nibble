---
id: extending-management-api
title: The management API and MCP
description: How apps, scripts and AI agents change a site's content as a person — the endpoints, signing in,
  operations, errors, and the rules that keep them safe.
order: 4
---

# The management API and MCP

The [content API](../theming/content-api.md) serves published content to other websites. This API is the other
half: it changes content, always as a person, through the same checks as the Control Plane. The `nibble` command and
AI apps use it; so can anything you build.

After reading this guide, you will know:

- The two ways in: HTTP and MCP.
- How an app signs in.
- The operations, and the rules every change follows.
- What errors look like, and how to act on them.

Agent access must be [turned on](../running/agent-access.md); until then these endpoints answer 404.

## 1. Two ways in

| Endpoint | For |
|---|---|
| `POST /api/v1/mcp` | MCP clients — Claude, ChatGPT, Codex, Cursor. Stateless JSON-RPC over HTTP; each operation is a tool |
| `GET /api/v1/operations` | the operations this token may use, with their arguments as JSON Schema |
| `GET /api/v1/operations/<operation>` | an operation that only reads; arguments in the query string |
| `POST /api/v1/operations/<operation>` | any operation; arguments as a JSON body |

Both are built from one list of operations, so they never disagree. Answers are never cached. Every `/api/v1/operations` answer
carries `Nibble-Api-Version`.

## 2. Signing in

The site is its own OAuth authorization server, for public clients only:

- **Discovery:** `/.well-known/oauth-protected-resource/api/v1/mcp` (or `/api/v1`) names the site as the authorization
  server; `/.well-known/oauth-authorization-server` describes it.
- **Authorization code with PKCE (S256)**, the only flow a browser takes. Loopback redirects may use any port.
- **Clients** identify themselves with a client metadata document (an `https` URL as `client_id`), register
  dynamically, or — the `nibble` command — are built in.
- **Tokens:** an access token lasts an hour; a refresh token rotates on every use, and reusing an old one disconnects
  the app. Tokens are bound to the endpoint they were issued for: an MCP token doesn't open the operations endpoints.
- **Device code**, only if the site allows it.

Send the token in the `Authorization` header. A token in a URL is refused.

## 3. Operations

| Group | Operations |
|---|---|
| Site | `whoami`, `describe_site`, `describe_schema`, `get_guide` |
| Entries | `list_entries`, `get_entry`, `create_entry`, `update_entry`, `transition_entry`, `list_revisions` |
| Terms | `list_terms`, `get_term`, `create_term`, `update_term`, `transition_term` |
| Globals and navigation | `get_global`, `update_global`, `get_navigation`, `update_navigation` |
| Assets | `list_assets`, `get_asset`, `upload_asset`, `update_asset`, `transition_asset` |
| Forms | `list_form_submissions` |

A token sees only the operations it may use. There is no search operation: search belongs to a theme's
[search page](../theming/queries.md#7-search).

## 4. Rules every change follows

- **Values follow `describe_schema`.** Unknown fields and arguments are refused with the names that would work.
- **Rich text is Markdown.** Images are `![alt](asset:ID)`; links may be web, email, phone or site paths only.
  Content Markdown can't hold — sets inside rich text — comes back as editor JSON.
- **`lock_version` is required** to change something. If someone saved it since you read it, the answer is
  `lock_conflict` with the current `lock_version`, and nothing is overwritten.
- **`dry_run: true`** checks a change completely and saves nothing.
- **`idempotency_key`** makes a retry safe: the same key returns the first answer instead of repeating the change.
- **Entries change as drafts.** Publishing is a separate operation.
- **Consequential changes wait for a person** when an app makes them: the answer is `approval_required` with an
  `approval_url`; once approved, send the same request with `approval`.
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

## 6. Telling agents about the site

Agents get a guide to the site — how to work, its content model — as the MCP server's instructions, as the
`nibble://guide` resource, and from `get_guide`. It's written from the schema and from the site's own notes in
`site/agents/*.md`, and never from content, so nothing a visitor writes can become an instruction. Put the editorial
rules you'd tell a new writer in `site/agents/voice.md`.

---
id: editing-ai-apps
title: Working with AI apps
description: Connect Claude, ChatGPT, Codex or Cursor to the site, choose what it may do, approve what it asks to
  publish, and disconnect it.
order: 7
---

# Working with AI apps

Tidewater's marketing lead drafts the weekly post with Claude, then reads it in the Control Plane before publishing.
This guide is how to set that up. It needs an administrator to have turned on [agent access](../running/agent-access.md).

After reading this guide, you will know:

- How to connect an app, and what each choice lets it do.
- How to approve what an app asks to publish.
- How to see what an app changed, and undo it.
- How to disconnect it.

## 1. Connecting an app

Open **Connected apps** from your account menu and copy the site's address for apps — for Tidewater,
`https://tidewater.example/api/v1/mcp`.

| App | Where to paste it |
|---|---|
| Claude (web, desktop) | Settings → Connectors → Add custom connector |
| ChatGPT | its connector settings, with developer mode on |
| Claude Code | `claude mcp add --transport http tidewater https://tidewater.example/api/v1/mcp` |
| Codex | `[mcp_servers.tidewater]` with `url = "https://tidewater.example/api/v1/mcp"` in `~/.codex/config.toml`, then `codex mcp login tidewater` |
| Cursor | its MCP settings, as a server with that URL |

`nibble mcp install --client claude-code` (or `codex`, `cursor`) does this for you — see
[The nibble command](../running/cli.md).

The app sends you to the site to sign in, then asks what it may do:

| Choice | The app may |
|---|---|
| **Read** | see the content you can see, and change nothing |
| **Draft** | create entries and change drafts, and send them for review; nothing goes live |
| **Everything I can do** | anything your role allows within the site's settings; each publish or live change waits for you |
| **Custom** | only what you tick, area by area |

The screen shows the app's name and the address it sends you back to. If you didn't start this from an app you
trust, choose **Cancel**.

> [!TIP]
> **Draft** is the right choice for writing. The app drafts, you read it in the Control Plane, and you publish.

## 2. Approving

With **Everything I can do**, an app that asks to publish, unpublish or trash something, or to change menus, globals,
terms or files, is told to wait for you. You get a notification; the app shows you a link. The page shows what would
change, and warns if the change links to another site. Confirm your password and **Approve**, and the app makes that
exact change, once — or **Decline** and nothing happens.

## 3. Seeing what an app did

Every change an app makes is yours, "via" the app. An entry's revisions show it — "by Mahfuz via Claude" — and any of
them can be restored, as with your own edits.

## 4. Disconnecting

**Connected apps** lists each app with what it may do and when it was last used. **Disconnect** stops it at once. An
app you haven't used for 30 days is disconnected by itself.

## 5. Tokens for scripts

For a script with no browser — a nightly import, a CI job — choose **Create token for a script** on the same page. It
acts as you, with the access you choose, and expires within 90 days. It's shown once: store it as a secret. Scripts
don't wait for approvals, so give a token only what the script needs.

## 6. From a terminal

The `nibble` command does the same work from a terminal — see [The nibble command](../running/cli.md):

```sh
nibble auth login tidewater.example
nibble remote list-entries --collection posts
```

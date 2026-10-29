---
id: editing-ai-apps
title: Connect an AI app and approve its changes
description: Connect Claude, ChatGPT, Codex or Cursor to the site, choose what it may do, approve what it asks to
  publish, and disconnect it.
order: 11
---

# Connect an AI app and approve its changes

Tidewater's marketing lead drafts the weekly post with Claude, then reads it in the Control Plane before publishing.
This guide is how to set that up. It needs an administrator to have turned on [agent access](../running/agent-access.md).

After reading this guide, you will know:

- How to connect an app, and what each choice lets it do.
- How to approve what an app asks to publish.
- How to see what an app changed, and undo it.
- How to disconnect it.

## 1. Connecting an app

Open **Connected apps** from your account menu and copy the address it shows for connecting apps.

| App | Where to paste it |
|---|---|
| Claude (web, desktop) | Settings → Connectors → Add custom connector |
| ChatGPT | its connector settings, with developer mode on |

Other apps, such as Claude Code, Codex and Cursor, are set up from a terminal. Ask your developer, or see
[The nibble command](../running/cli.md).

The app sends you to the site to sign in, then asks what it may do:

| Choice | The app may |
|---|---|
| **Read** | see the content you can see, and change nothing |
| **Draft** | create entries and change drafts, and send them for review; nothing goes live |
| **Everything I can do** | anything your role allows within the site's settings |
| **Custom** | only what you tick, area by area |

The screen shows the app's name and the address it sends you back to. If you didn't start this from an app you
trust, choose **Cancel**.

> [!TIP]
> **Draft** is the right choice for writing. The app drafts, you read it in the Control Plane, and you publish.

## 2. Approve what an app asks to publish

With **Everything I can do**, an app that asks to publish, unpublish or trash something, or to change menus, site settings,
labels or files, is told to wait for you. You get a notification; the app shows you a link. The page shows what would
change, and warns if the change links to another site. Confirm your password and **Approve**, and Nibble makes that
exact change, once — or **Decline** and nothing happens. If the change can no longer be made, because someone edited
the same thing or the app's access changed, the page says why and nothing is altered. **Connected apps** lists the
requests waiting for you, and several can be approved at once.

When connecting an app you may let it make these changes without asking, after confirming your password. The site
can require every app to ask, and an app signed in with a code always does.

## 3. Seeing what an app did

Every change an app makes is yours, "via" the app. An entry's revisions show it — "by Mahfuz via Claude" — and any of
them can be restored, as with your own edits.

## 4. Disconnecting

**Connected apps** lists each app with what it may do and when it was last used. **Disconnect** stops it at once. An
app you haven't used for 30 days has to sign in again; one you keep using stays connected.

## 5. Tokens for scripts

For a script with no browser — a nightly import, a CI job — choose **Create token for a script** on the same page. It
acts as you, with the access you choose, and expires within 90 days. It's shown once: store it as a secret. Scripts
don't wait for approvals, so give a token only what the script needs.

## 6. Setting it up from a terminal

Developers can connect apps and run the same actions from a terminal. See [The nibble command](../running/cli.md).

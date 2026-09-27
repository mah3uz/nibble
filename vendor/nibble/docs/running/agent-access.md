---
id: running-agent-access
title: Agent access
description: Let people connect Claude, ChatGPT, Codex, Cursor and the nibble command to the site, decide what those
  apps may touch, and see and disconnect every one of them.
order: 8
---

# Agent access

Tidewater's marketing team want to draft posts from Claude, and the developer wants to fix a typo from a terminal
without opening the Control Plane. Agent access is how a site allows that, and how an administrator keeps it narrow.

After reading this guide, you will know:

- What a connected app can and can't do, and why it can never do more than the person who connected it.
- How to turn agent access on, and choose what apps may touch.
- Who may connect apps, and how to see and disconnect them.
- What makes an app wait for a person, and why.

## 1. What a connected app is

A person connects an app by signing in to the site from it and choosing what it may do. From then on the app works
**as that person**: every change is recorded as theirs, "via" the app, in revisions and the audit log.

What an app may do is the **smallest** of three things, checked on every request:

1. **The person's roles.** An app connected by an Author can never publish, because the Author can't.
2. **What the person chose when connecting it:** read only, drafts only, everything they can do, or area by area.
3. **What this page allows.** Turn writing to navigation off here and every app loses it on its next request, without
   anyone reconnecting.

Removing someone's role, or their account, ends their apps' access at once.

## 2. Turning it on

Agent access is off until an administrator turns it on. Open **Users → Agent access**, switch on **Let people connect
AI apps**, and save.

Below the switch is a table of every area of the site — each collection and taxonomy, globals, navigation, assets
and form submissions — with a switch for **Read**, **Write**, **Publish** and **Delete**. When you first turn agent
access on, apps may read content and write entry drafts, and nothing else.

| Area | Write means | Why it starts off |
|---|---|---|
| A collection | creating entries and changing drafts | on: a draft doesn't change the live site |
| A taxonomy, globals, navigation | changing them | these have no drafts, so a change is live at once |
| Assets | uploading and changing files | an uploaded file has a public address straight away |
| Form submissions | — (read only) | visitors wrote them, and they may hold personal details |

Collections kept as files offer only **Read**: their entries live in the site's repository.

> [!TIP]
> Turn on only what someone asked for. "Marketing wants Claude to draft blog posts" needs **Posts: Read, Write** and
> nothing more.

## 3. Who may connect apps

A person needs the **Connect apps** permission. Administrators have it; give it to other roles under **Roles**. The
Agent access page lists which roles hold it.

**Signing in with a code** lets an app on a server, with no browser, sign in by showing a code the person types into
the Control Plane. Codes can be phished — someone sends a code and asks you to "verify" it — so the switch stays off
unless someone needs it, and even then an app signed in this way can never have *everything I can do*.

## 4. Approvals

Some changes don't wait for a person to publish them, or can't be quietly undone: publishing, unpublishing or
trashing an entry, and any change to terms, globals, navigation or assets. When a connected app asks to make one,
Nibble first checks it would succeed, then holds it and tells the app to ask its person. The person sees exactly what
would change — with a warning if it links to another site — confirms their password, and approves it. The app then
makes that change, once.

Tokens a person creates for their own scripts (under **Connected apps**) don't wait: nobody is there to approve.

## 5. Seeing and disconnecting apps

The bottom of the Agent access page lists every connected app on the site: whose it is, what it may do, when it was
last used and from where, and when it expires. **Disconnect** ends it immediately.

Each person sees their own under **Connected apps** in their account menu, and gets a notification whenever a new
app is connected to their account. An app's sign-in lasts 90 days at most, and ends after 30 days unused.

## 6. What stays protected

- **An app never sees a password.** People sign in to the site itself, with their password, two-factor code or
  passkey.
- **Hard deletes aren't possible.** Apps trash; a person empties the trash.
- **Every change keeps its history.** Revisions show who made it and through which app, so it can be undone.
- **Users, roles, tokens, webhooks, redirects and settings are never available to apps.**

> [!IMPORTANT]
> Apps read content that other people wrote — a form submission, a comment, someone else's post — and an app can be
> tricked by instructions hidden in it. The limits on this page are what stop that turning into a change on the live
> site. Keep them as narrow as the work needs.

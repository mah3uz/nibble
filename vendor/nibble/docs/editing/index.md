---
id: editing
title: Editing content
description: A tour of the Control Plane for the people who write the site — the dashboard, the sidebar, search and
  your account.
order: 4
---

# Editing content

This section is for you if you write the site. At Tidewater that is the marketing team: you write the blog, build
landing pages and answer demo requests, and you almost never need a terminal. Everything here happens in the
browser, at `/cp`, the Control Plane.

After reading this guide, you will know:

- What is on the dashboard, and how to change it.
- How the sidebar is organised, and why yours may differ from a colleague's.
- How to search everything.
- Where your account, sessions and two-factor authentication live.
- The words this section uses, and the ideas that make the rest of the Control Plane make sense.
- Where to look for a task.

> [!NOTE]
> Almost nothing in this section needs a terminal, and nothing here can break the site's code. The worst an editor can do
> is publish something they did not mean to — and that can always be undone.

## 1. The dashboard

Signing in lands on the dashboard: what has been published and edited lately, form submissions, uploads, and the
entries changed most recently.

![Tidewater's dashboard](../../images/cp/dashboard.png)

Choose **Customize** to add, remove and rearrange widgets. **Top missing pages** is worth adding: it lists the
addresses visitors asked for and did not find. See [Redirects and SEO](redirects-and-seo.md).

## 2. The sidebar

| Group | Holds |
|---|---|
| **Content** | each collection — Tidewater's Help centre, Pages and Blog — its label lists, Authors and Topics, and Assets |
| **Structure** | Site settings and Navigation — the site's settings and menus |
| **Tools** | Forms, Types, Trash, Redirects, Webhooks, Updates and Utilities |
| **Users** | Users, Roles, API tokens and Agent access |

**Types** is a read-only map of the fields each kind of content has. Look there to see what a page type holds; you can't change anything on it.

You only see what your role allows. A shorter sidebar than a colleague's is not a fault; it is the role you were
given. See [Users and roles](../running/users-and-roles.md).

## 3. Search

**Search** at the top of every screen — or `Ctrl-K` — finds entries, labels, assets and screens by what is in them, not
only by title. Choose **Keyboard shortcuts** in your account menu for the list of shortcuts.

## 4. Notifications and Back

The bell shows what needs you: a review requested, an entry approved or sent back, a mention, a form submitted, an
app asking for approval. It lists the latest first, and **Load more** brings older ones. **Mark all read** and **Clear all** tidy it up. When a scheduled task
starts failing, administrators get a notification that opens **Utilities → Scheduled tasks**.

The browser's Back button closes the dialog or panel you have open, the innermost first, before it takes you to the
previous page.

## 5. Your account

The circle with your initials, top right, opens your account: your name and password, two-factor authentication,
passkeys, and a few preferences. See [Set up your account and sign in safely](your-account.md).

> [!TIP]
> Turn on two-factor authentication. An editor account can publish to the public site; a stolen password should
> not be enough to do that.

Two things happen automatically, and are worth knowing before they surprise you:

- **Sensitive screens ask for your password again** — users, roles, API tokens, imports, agent access, approvals and the Integrations settings.
- **After a while without activity you are locked out** until you enter your password again. A "Your Session is
  Expiring" warning comes first, with an **Extend Session** button, so nothing you are writing is lost.

## 6. Words and ideas worth five minutes

**Entry, collection and label.** An *entry* is one piece of content: a page or a post. A *collection* is a group of
entries of the same kind: Pages, Blog, Help centre. A *label* is a tag you sort entries by, such as an author or a
topic; your site gives its lists their own names, such as Categories or Tags. Each kind of page has its own list of fields, called its *type*. Whoever builds the site decides
these, which is why the form you see fits the content rather than being one big text box. If a field is missing or
confusing, that is a conversation with them — and usually a small change.

**Nothing is lost.** Saving a live page creates a draft rather than changing the site. Every publish keeps a revision
you can go back to. Deleting moves things to the trash, where they wait before disappearing. You would have to work
quite hard to lose anything.

## 7. Pages you cannot edit

Tidewater's **Help centre** opens like any other collection, but its pages are locked, and each one says which file
it is written in. That is deliberate: the help centre is written in files, alongside the product's code, and an edit
here would be replaced the next time the site is updated. Ask whoever writes it. See
[Content as files](../modelling/content-as-files.md).

## 8. The guides in this section

| Guide | Covers |
|---|---|
| [Write and organise pages and posts](entries.md) | writing a page or a post, its fields, blocks, its URL, deleting it |
| [Save, preview and publish](publishing.md) | drafts, previews, publishing, scheduling, review, revisions and recovering from a failed save |
| [Add and edit categories and tags](categories-and-tags.md) | the labels you sort content by |
| [Upload and manage images and files](assets.md) | uploading, replacing, renaming, moving, cropping, alt text |
| [Restore something you deleted](trash.md) | the trash, restoring and deleting for good |
| [Build and arrange the site's menus](navigation.md) | building the menus |
| [Change the site's settings](site-settings.md) | the site's name, logo, contact details and defaults |
| [Find and handle form submissions](form-submissions.md) | what people sent, spam, failed deliveries, exporting, one person's data |
| [Fix search results, share cards and broken links](redirects-and-seo.md) | search results, share cards, redirects and missing pages |
| [Add analytics and custom code](analytics.md) | analytics tools, consent, and snippets of your own on every page |
| [Connect an AI app and approve its changes](ai-apps.md) | connecting Claude or ChatGPT, and approving what they ask to publish |
| [Set up your account and sign in safely](your-account.md) | password, two-factor sign-in, passkeys, preferences |

## 9. Common tasks

| I want to | Go to |
|---|---|
| Change the site's name, logo or footer details | [Change the site's settings](site-settings.md) |
| Swap an image everywhere it is used | [Replace or Reupload](assets.md#51-replace-or-reupload) |
| Restore a deleted page | [Restore something you deleted](trash.md) |
| Undo removing a block | [Working with blocks](entries.md#working-with-blocks) |
| Find a form submission, or mark spam as not spam | [Find and handle form submissions](form-submissions.md) |
| Set up two-factor sign-in | [Turn on two-factor sign-in](your-account.md#3-turn-on-two-factor-sign-in) |
| Send a page live on a date | [Scheduling](publishing.md#31-scheduling) |
| Fix a link that leads nowhere | [Missing pages](redirects-and-seo.md#4-missing-pages) |
| Export or erase one person's data | [Find or erase one person's data](form-submissions.md#6-find-or-erase-one-persons-data) |

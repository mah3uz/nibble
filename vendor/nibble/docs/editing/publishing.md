---
id: editing-publishing
title: Drafts and publishing
description: Saving is not publishing — drafts, live preview, publishing, scheduling, review, revisions and
  unpublishing.
order: 2
---

# Drafts and publishing

The most important idea in the Control Plane: **saving is not publishing.** This guide follows your post
announcing payment reminders from first draft to the site, and back.

After reading this guide, you will know:

- What saving does to a new entry and to a live one.
- How to preview a draft exactly as the site will show it.
- How to publish now, or schedule for later.
- How review works when a site turns it on.
- How to go back to an earlier version, and how to take something off the site.
- What visitors see, and when.

## 1. Drafts

A new entry is a draft until it is published: nobody outside the Control Plane can see it. **Save draft** keeps your
work; do it as often as you like.

An entry that is already live works the same way. **Save changes** stores your edits as a **draft of the live
entry** — the site keeps showing the published version until you publish the draft. That is what makes it safe to
rework a landing page over several days, hand it to a colleague for a look, or change your mind.

**Discard changes** throws the draft away and goes back to what is live.

## 2. Previewing

**Live Preview** shows the draft exactly as the site will render it — the real theme, the real layout — with a
**Preview** ribbon in the corner so nobody mistakes it for the live page. It updates in place as you type, where you
were reading. Use it before publishing, rather than publishing to see what
something looks like.

## 3. Publishing

**Publish** — or **Publish changes**, for a live entry — puts it on the site. From that moment visitors see it, the
sitemap lists it, site search finds it and, for the blog, the feed carries it.

An entry with no publish date takes the moment you publish it.

**Publish changes** asks for a short message about what changed, which the entry's history keeps beside the revision.
It is optional. To stop being asked, open the arrow beside the button and choose **Publish straight away**; the
choice is remembered for you alone, and **Ask for a message** brings the question back.

### 3.1 Scheduling

Give an entry a **publish date** in the future, in the column on the right, and publishing schedules it instead: the
button reads **Schedule**. A job runs every minute and publishes whatever has come due, so nobody needs to be at a
desk when it happens.

Tidewater announces features at 9am on Tuesdays. You write the post the week before, set the date, and schedule
it.

Collections that allow it also have an **unpublish date** — for an offer or an event that ends.

> [!NOTE]
> A scheduled entry shows as **Scheduled** in the listing and on the dashboard. **Publish now** on a scheduled entry
> ignores the date and publishes at once.

## 4. Review

Some collections require review: whoever wrote an entry cannot publish it themselves.

1. The author chooses **Submit for review**. The entry shows as **In review**.
2. Someone whose role may approve opens it, previews it, and chooses **Approve**, or **Send back** to return it to
   draft for another round.
3. Once approved, it is published — by the approver, or by anyone whose role may publish.

Each step is recorded in the entry's history. If a collection does not use review, you will never see these buttons.

> [!NOTE]
> Your developer turns review on for a collection. Tidewater's blog has it, since a second writer joined. See
> [Collections](../modelling/collections.md#6-publishing-drafts-and-revisions).

## 5. Revisions

Every publish keeps a **revision**. **History**, at the top of the editor, lists them: who published what, and when.

**Restore** on any revision makes a **new draft** from it rather than changing the live page, so you can look at it,
change your mind, and publish or discard it. Going back is never itself a risky act.

## 6. Unpublishing

**Unpublish** takes an entry off the site and keeps everything about it. It is not deletion: nothing is thrown away,
and it can be published again at any time. A visitor who follows an old link finds a missing page, which is
counted — see [Redirects and SEO](redirects-and-seo.md).

> [!WARNING]
> Unpublishing a page that is in a menu, or that other pages link to, leaves those links pointing at nothing until
> you put it back or add a redirect.

## 7. What visitors see, and when

Publishing updates the site immediately. Pages are cached for speed, and publishing clears exactly the pages that
used what changed — the post itself, the blog listing, the home page if the post appears there, the feed. You never
have to think about the cache, and you should never have to wait for it.

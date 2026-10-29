---
id: editing-entries
title: Write and organise pages and posts
description: Find, write and organise pages and posts — the listing, the editor, blocks, URLs, nesting and deleting.
order: 1
---

# Write and organise pages and posts

An entry is one piece of content: a landing page, a blog post, a customer story. A collection is a group of entries of
the same kind, such as Pages or Blog. This guide follows you writing
Tidewater's announcement of payment reminders.

After reading this guide, you will know:

- How to find entries, and make the listing show what you need.
- How to write one, and what the editor's tabs hold.
- Where an entry's URL comes from, and what happens when it changes.
- How pages are nested and ordered.
- How deleting and restoring work.

## 1. The listing

Open a collection in the sidebar — **Blog** — and its entries are listed.

![The blog's listing](../../images/cp/blog-listing.png)

- **Search** narrows the list by title as you type.
- **Filters** narrow it by status, kind of page, language, author or topic. **Save view** keeps a combination you use
  often as a tab beside **All** and **Drafts**.
- The **columns** button, on the right, chooses which fields are shown. Your choice is remembered.
- The **download** button beside it exports the list as a CSV file.
- Click a column heading to sort by it.
- Columns for fields such as a number, a date or a choice sort too, and fields that offer a filter (a choice, a yes/no
  switch or a date) add it under **Filters**: tick the options you want, pick yes or no, or give a from and to date.
  Entries with nothing in a sorted column stay at the bottom. Which fields offer these is the site's choice.

Tick entries to act on several at once: publish, unpublish, move, add a topic or move to the trash.

> [!NOTE]
> What you see is what you may do. If your role cannot publish, there is no Publish button — not a button that
> tells you off when you press it.

Structured collections, such as **Pages**, also have a **tree** view, and dated ones, such as **Blog**, a **calendar**.
Switch between them with the buttons at the top right.

## 2. Writing an entry

Choose the button at the top right — **New blog** here; its label is made from the collection's title — and the
editor opens:

![A page open in the editor](../../images/cp/page-editor.png)

The fields come from the kind of page you chose. Whoever built the site decides which fields each kind has.
Tidewater's posts have:

| Where | Holds |
|---|---|
| **Content** tab | the title, an excerpt and the body |
| **SEO** tab | how the post looks in search results and when shared — see [Fix search results, share cards and broken links](redirects-and-seo.md) |
| the column on the right | the slug, the publish date, the author, topics, featured image and template — and the parent page in a structured collection |

On a narrow screen the right-hand column folds into a tab of its own, called **Details**.

Below it, **Notes** is for the team: leave one, and `@mention` someone to tell them. Notes never reach the site.

Fields with a red asterisk (*) are required. The form tells you what is missing when you save, rather than failing
silently. Some fields are only required in some cases, depending on what you filled in elsewhere on the page. The asterisk
appears on them when they become required, and goes when they don't.

Some fields worth knowing by name:

| Field | What to expect |
|---|---|
| **Rich text** | a full editor: headings, lists, links, images, tables, code and find-and-replace |
| **Markdown** | plain text with simple symbols for headings and bold (Markdown), with a Preview button that shows exactly what the site will render |
| **Assets** | opens the media library, so you choose an image rather than upload another copy |
| **Entries**, or a label list such as **Topics** | a picker for other entries or labels — an author, a topic, related posts. To make a new label, see [Add and edit categories and tags](categories-and-tags.md) |
| **Page blocks** | build a page from blocks in any order: text, quote, call to action, image, gallery, pricing |

### Picking and creating related items

A field that points at other entries or labels shows a dropdown when there are only a few to choose from, and a search
box when there are many. Under it, **Create a new …** lets you add one without leaving the entry: type its title, and it
is chosen for you. A new entry is saved as a draft; a new label is live at once. The option only appears if your role
lets you create that kind of item.

### Working with blocks

A block is one building piece of a page: a quote, an image, a pricing table. Use the add button under the blocks
to add one, and fill it in.

- **Move a block.** Open the **⋯** menu on the block and choose **Move up** or **Move down**.
- **Copy a block.** Choose **Copy block** in the same menu. You see "Block copied".
- **Paste a block.** Open another entry, or another place on the page. The add button then offers **Paste**. It only
  appears when that field has the same kind of block. The pasted block is a separate copy, so changing it
  does not change the first.
- **Undo a removal.** Choose the bin on a block to remove it. For a few seconds the message "Block removed" offers
  **Undo**. Removing a row of a table field, such as opening hours, works the same way ("Row removed"). After the
  message goes, the block is gone unless you [restore an earlier version](publishing.md#5-revisions).

> [!IMPORTANT]
> **Saving does not publish.** Save as often as you like; the site does not change until you publish. See
> [Save, preview and publish](publishing.md) — it is the one thing most worth understanding on your first day.

### Duplicate an entry

**Duplicate**, beside **Trash** in the editor and in a row's menu in the listing, makes a copy to start from. The copy is a
new draft in the same collection and language, titled "Title (copy)", with its own address. It is not published and
has no history or schedule, and you land on it straight away.

Fields are copied as they are, including blocks and rows, and the same images and linked entries. Read-only fields, and
fields set not to be copied, start empty or at their default. A field whose value must be different in every entry,
such as a unique code, is not copied. Duplicate appears only if you can create entries in the collection, and never for
a collection kept in the site's files.

## 3. URLs

An entry's address comes from two things: the pattern its collection uses — Tidewater's blog addresses look like
`/blog/introducing-payment-reminders` — and the entry's **slug**, the readable part. The slug is filled in from the title as you type, and you can change it in the
column on the right.

**Change the slug of an entry that is already live, and Nibble records a redirect from the old address to the new one.**
Links you have shared, other sites linking to you and search results all keep working. You can see the redirect
under **Redirects**.

> [!TIP]
> Title your post "Introducing payment reminders" and the slug comes out as
> `introducing-payment-reminders`. Shorter slugs read better in a shared link — `payment-reminders` — and it is
> cheapest to change one before the post is first published.

## 4. Nesting and ordering pages

In a structured collection — **Pages** — entries sit under one another. Use the tree view to drag a page under
another, or choose its **Parent** in the column on the right. The URL follows the structure, so moving `/integrations`
under `/features` makes it `/features/integrations`, with a redirect recorded from the old address.

The page whose slug is `home`, at the top level, is the site's home page.

## 5. Deleting and restoring

**Trash**, at the top right of the editor, moves the entry to the trash. It leaves the site at once, and waits in
**Tools → Trash**, where it can be restored — URL and all — until the trash is emptied, 30 days later unless the site
says otherwise.

See [Restore something you deleted](trash.md) for restoring it, or deleting it for good.

A page with pages under it cannot be trashed until they are moved or trashed first.

> [!WARNING]
> If other entries link to the one you are trashing — a menu, a related post — Nibble lists them and asks you to
> confirm. Those links break until you restore the entry or point them somewhere else.

---
id: editing-redirects-and-seo
title: Fix search results, share cards and broken links
description: How pages look in search results and when shared, how old links keep working, and how to find and fix
  the addresses visitors cannot reach.
order: 9
---

# Fix search results, share cards and broken links

Most of this looks after itself. This guide is about knowing that, and about the screens where you can step in.

After reading this guide, you will know:

- How a page's search result and share card are decided, and how to override them.
- What happens to old links when a page moves.
- How to add a redirect of your own.
- How to find the addresses visitors ask for and do not find.

## 1. On each entry

Every page and post has an **SEO** tab: the title search engines show, the description beneath it, the preferred address for the page (used when the same page can be reached at more than one address),
the image used when someone shares the link, and two switches that keep the page out of search results or out of the
sitemap.

Leave them empty and they fall back to what the entry already has — its title, its excerpt, its featured image — and
then to the site's defaults under **Site settings → SEO**. A page is never unlabelled. Fill them in when the page's own
title is not the one you want in a search result.

Three settings are worth knowing:

- **Use this title as written** keeps the site's title template — usually the site's name after the title — off this
  page, so the tab and the share card show exactly the SEO title, or the page's title when the SEO title is empty.
- **Share image** is chosen from the [media library](assets.md), like any other image, not typed as an address. Only
  images can be chosen, one per page.
- **Hide from search engines** and **Leave out of the sitemap** are different. The first asks search engines not to
  list the page, and also drops it from the sitemap. The second only drops it from the sitemap; the page can still
  appear in search results.

> [!TIP]
> Write descriptions for people, not for search engines: one sentence that tells someone whether this is the page
> they want. Tidewater's for the pricing page is "Three plans, no setup fee, cancel whenever you like."

## 2. Sitemaps and robots.txt

The site's sitemap, a list of your pages for search engines, is generated from what is published and stays current as you publish. You never edit it, and
there is nothing to resubmit after a change. `robots.txt`, the file that tells search engines which pages to skip, is generated too. Both are covered in
[SEO, sitemaps and feeds](../theming/seo-and-feeds.md).

## 3. Redirects

**Redirects**, under Tools, lists every redirect on the site, a page at a time. Search matches the **From** and **To**
addresses, and **From**, **Hits** and **Last hit** sort the list.

![Redirects, with one recorded when a post's slug changed](../../images/cp/redirects.png)

Most appear on their own. Shorten a live post's slug from `why-late-invoices-are-a-design-problem` to
`late-invoices`, and a redirect from the old address is recorded at once — links already shared keep working.

| Column | Shows |
|---|---|
| **From**, **To** | the old address and where it sends visitors |
| **Status** | in words: Permanent or Temporary. Two more options keep a visitor's form data intact; they are for forms and apps, and most people never need them |
| **Added** | **Manual** if someone added it, **Automatic** if Nibble recorded it when an address changed, **Imported** if it came in with a content package |
| **Hits**, **Last hit** | how often it has been used, and when last |

Add your own with **Add redirect**, and change one by choosing its row. In the dialog, **From** is a path on this site,
like `/old-page`; end it with `/*` to redirect everything under it:
`/old-blog/*` sends every address that starts with `/old-blog/`. **To** is a path on this site or a full
`https://` address, and typing `/` in it suggests pages and posts to choose from. Permanent suits an address that has
moved for good; Temporary suits one that will come back. (Browsers know them as 301 and 302.) Adding your own is what you want when moving to Nibble from
another site: bring the old site's addresses across, and years of links and search ranking come with them.

Tick rows to **Delete** several at once.

> [!NOTE]
> Chains are collapsed as they are made. If `/a` redirects to `/b` and you then redirect `/b` to `/c`, `/a` is
> repointed straight to `/c`, so every old address arrives in a single hop.

> [!WARNING]
> A redirect wins over a page. If you add a redirect *from* an address a live page uses, visitors go where the
> redirect sends them, not to the page.

## 4. Missing pages

**Missing pages** lists every address visitors asked for and did not find, a page at a time and searchable by path,
with **Hits** and **Last seen**:

![Missing pages, most-requested first](../../images/cp/not-found.png)

It is the most useful SEO screen in the Control Plane, and the least glamorous. A path near the top is real people,
repeatedly, failing to reach something — usually a link from an old site or a mistyped address in a newsletter.
**Add redirect** opens the redirect dialog with **From** already filled in, so only the destination is left to
choose, and fixes it for everyone who follows. **Dismiss** removes a row that needs nothing.

The dashboard's **Top missing pages** widget shows the first few — add it with
**Customize** on the dashboard.

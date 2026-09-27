---
id: theming-seo-and-feeds
title: SEO, sitemaps and feeds
description: What search engines, social networks and feed readers receive from a Nibble site, and the settings that
  shape it.
order: 4
---

# SEO, sitemaps and feeds

A startup's site earns most of its visitors from search and from links people share. This guide covers everything
Tidewater's site tells search engines, social networks and feed readers — most of which needs no work at all.

After reading this guide, you will know:

- Where a page's title, description and share image come from.
- How the SEO global sets defaults for the whole site.
- How sitemaps and `robots.txt` are generated, and when a site asks not to be indexed.
- How to publish Atom feeds.

## 1. Page titles, descriptions and share images

Every blueprint that imports `nibble::seo` gives editors an **SEO** tab: a title, a description, a share image, a
canonical URL, a "hide from search engines" switch, and the kind of structured data the page is.

Left empty, each falls back to something sensible:

| Tag | Comes from |
|---|---|
| title | the SEO title, else the entry's title — then put through the site's **title template** |
| description | the SEO description, else the entry's excerpt, else the site's default description |
| share image | the SEO image, else the featured image, else the site's default share image |
| canonical URL | the SEO canonical URL, else the page's own URL |

So a post published without anyone touching the SEO tab still has a proper title, description and share card.

The page gets its title, description, canonical link and robots tag from `SeoHead`, and its Open Graph and Twitter
tags, structured data and verification tags from the HTML Nibble sends. See
[Theme components](components.md#4-seo-and-previews).

## 2. Site-wide defaults

**Globals → SEO** holds the defaults:

| Field | Tidewater's |
|---|---|
| Title template | `{title} · Tidewater` — tokens are `{title}` and `{site_name}` |
| Default description | "Invoicing software that gets small agencies paid." |
| Default share image | a card with the logo |
| Organization name and logo | used in structured data |
| Verification tags | the tags Google Search Console and others ask you to add |

## 3. Sitemaps

`/sitemap.xml` is an index pointing at one sitemap per collection and taxonomy with a route —
`/sitemap-posts.xml`, `/sitemap-help.xml`, `/sitemap-taxonomy-topics.xml`. They list published content only, stay
current as content is published, and include pages [written as files](../modelling/content-as-files.md).

Tune a collection's entry, or leave it out:

```yaml
# site/schema/collections/posts.yml
sitemap:
  priority: 0.8
  changefreq: weekly
```

```yaml
sitemap:
  enabled: false
```

An entry whose SEO tab says "hide from search engines" is left out of the sitemap and marked `noindex`.

## 4. robots.txt, and sites that should not be indexed

`/robots.txt` is generated. On the production site it allows everything and names the sitemap:

```
User-agent: *
Allow: /

Sitemap: https://tidewater.example/sitemap.xml
```

Anywhere else — development, or production with `NIBBLE_BLOCK_INDEXING` set — it disallows everything, every page
is marked `noindex, nofollow`, and analytics stay off.

> [!IMPORTANT]
> Set `NIBBLE_BLOCK_INDEXING=1` on any public server that is not the real site: a demo, a preview, a copy for
> testing. Otherwise it competes with your real site in search results.

## 5. Feeds

A collection with `feed` publishes an Atom feed of its newest published entries:

```yaml
# site/schema/collections/posts.yml
feed:
  title: The Tidewater blog
  limit: 20
```

| URL | Holds |
|---|---|
| `/feed-posts.xml` | the blog |
| `/feed.xml` | every collection with a feed, newest first |

Each item carries the entry's title, URL, date and — when the entry has one — its `excerpt` or `description` as the
summary. `feed: true` uses the collection's title and the newest 50 entries.

> [!NOTE]
> Feeds read entries from the database, so a collection [written as files](../modelling/content-as-files.md) has
> no feed.

## 6. Redirects and missing pages

Moving pages without losing their search ranking is covered from the editor's side in
[Redirects and SEO](../editing/redirects-and-seo.md): changing a live entry's slug records a 301 automatically,
chains are collapsed to a single hop, and every 404 is counted so it can be redirected.

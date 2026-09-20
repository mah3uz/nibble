---
title: Redirects and SEO
description: Titles, descriptions, sitemaps and redirects.
order: 6
---

# Redirects and SEO

## On each entry

An entry's SEO fields set its title, description and sharing image. Left empty, they fall back to what the page
already has, so a page is never unlabelled — filling them in is an override, not a requirement.

## Sitemaps and robots

`sitemap.xml` is generated from published content and kept current as you publish. `robots.txt` is generated too.
On staging, both tell crawlers to stay away.

## Redirects

**Redirects** lists every redirect on the site. Most appear on their own: changing a published entry's slug
records one from the old URL. You can also add your own — useful when moving to Nibble from another site.

Chains are collapsed as they are made, so a URL redirected twice still arrives in one hop.

## 404s

The **404 monitor** lists paths people asked for and did not find, most-requested first, so a redirect can be
added where it will actually help.

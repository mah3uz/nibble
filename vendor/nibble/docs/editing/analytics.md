---
id: editing-analytics
title: Analytics and custom code
description: Add analytics tools and snippets of your own to every live page, pause them, and know which need
  consent.
order: 8
---

# Analytics and custom code

Tidewater counts visits with Plausible and runs a chat widget from a snippet its support tool gave it. Both are set up
under **Globals → Integrations**, without touching the theme.

After reading this guide, you will know:

- How to add an analytics tool, and where to find what it asks for.
- Which tools need a visitor's consent.
- How to add a snippet of your own, and where it goes on the page.
- How to pause either without losing its settings.

> [!NOTE]
> Analytics and custom code load on the live site only: not in previews, the Control Plane, or while indexing is
> blocked. A test visit from a staging server never shows up in your numbers.

## 1. Analytics

Open **Globals → Integrations → Analytics** and choose **Add analytics**. Pick a tool, and a card opens with only
the fields that tool needs. Add as many as you like; the tab's name counts those that are running, as in
**Analytics · 2**.

| Tool | Asks for | Where to find it |
|---|---|---|
| Plausible | the script URL, and a domain only for the older `script.js` | Plausible → Site settings → Site installation: the `src` of the script |
| Fathom | the site ID | Fathom → Settings → Sites → Embed code |
| Umami | the website ID, and a script URL only when self-hosted | Umami → Settings → Websites → Edit |
| Cloudflare Web Analytics | the token | Cloudflare → Analytics & Logs → Web Analytics → Manage site: the token in the JS snippet |
| Google Analytics 4 | the measurement ID, `G-…` | Google Analytics → Admin → Data streams → your web stream |
| Google Tag Manager | the container ID, `GTM-…` | Tag Manager, beside the container's name |
| Script tag | a script URL and its `data-` attributes | the tool's install instructions |

Nibble writes each tool's tags itself, as its vendor's install instructions show them: [Plausible](https://plausible.io/docs/plausible-script),
[Fathom](https://usefathom.com/docs/script/embed), [Umami](https://docs.umami.is/docs/tracker-configuration),
[Cloudflare](https://developers.cloudflare.com/web-analytics/get-started/),
[Google Analytics](https://developers.google.com/tag-platform/gtagjs/install) and
[Tag Manager](https://developers.google.com/tag-platform/tag-manager/web), and each card links to its guide. Under
**What Nibble writes**, **Show the tags Nibble writes** shows them exactly, to compare with the vendor's page. An ID in
the wrong shape is explained there as you type, with the shape it should have, and refused when you save.

The public site changes pages without a full reload, and every tool here counts those page changes. Tools that need
to be told, Fathom and Cloudflare, are told. For Google Analytics, keep **Enhanced measurement → Page changes based on
browser history events** on, as it is by default; in Tag Manager, a **History Change** trigger does the same.

Nibble sets no Content Security Policy for scripts, so each tool loads as it is. A site that adds its own policy has
to allow every tool's script and the address it sends visits to.

Cloudflare Web Analytics can be added once, since a page carries one beacon. Two Google Analytics cards share one
loader, each sending to its own property.

> [!TIP]
> Use **Script tag** for a tool not in the list that loads from one script tag, such as `<script defer
> src="https://…" data-site="…">`. Anything more than that belongs in custom code.

### 1.1 Consent

Each tool carries a badge. **No cookies**: Plausible, Fathom, Umami and Cloudflare keep nothing on the visitor's
device, and don't need a consent banner. **Needs consent**: Google Analytics and Tag Manager set cookies, which in the
EU and the UK needs the visitor's agreement first.

Nibble has no consent banner of its own. If your site needs one, add your consent tool as custom code, and set it up
to hold back the tools marked **Needs consent** until a visitor agrees.

## 2. Custom code

**Custom code** holds snippets a tool gives you to paste into a page: a chat widget, a heatmap, a verification tag.
Choose **Add snippet**, name it, choose where it goes and paste the code into the editor. A collapsed card reads
as its name and place, such as "Chat widget · At the end of the body".

| Where | For |
|---|---|
| **In the head** | most tools, and anything that asks to be "before `</head>`" |
| **At the start of the body** | a snippet that asks to be "immediately after `<body>`" |
| **At the end of the body** | widgets that draw on the page, and anything that asks to be "before `</body>`" |

Snippets in the same place are written in the order of their cards; drag a card to move it.

> [!CAUTION]
> A snippet is added to every live page exactly as written, and runs for every visitor. Only paste code from sources
> you trust, and only when you know what it is for.

## 3. Pausing and removing

The eye on a card pauses it: its settings stay, and nothing of it reaches the site until you turn it back on. A paused
card isn't counted in the tab's name. The bin removes a card for good.

Saving clears every cached page, so a change reaches visitors straight away.

## 4. Who can change these

Anyone whose role may edit the **Integrations** global. That permission is separate from the other globals, and AI
apps connected to the site can't reach Integrations at all. See [Users and roles](../running/users-and-roles.md).

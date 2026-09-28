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

Open **Globals → Integrations → Analytics** and choose **Add analytics**. Pick a tool, then paste its snippet into
the card exactly as the tool gives it: every tool has one on its install page, and each card says where. Add as many
tools as you like; the tab's name counts those that are running, as in **Analytics · 2**.

| Tool | Where its snippet is | Goes |
|---|---|---|
| [Plausible](https://plausible.io/docs/plausible-script) | Site settings → Site installation | in the head |
| [Fathom](https://usefathom.com/docs/script/embed) | Settings → Sites → Embed code | in the head |
| [Umami](https://docs.umami.is/docs/tracker-configuration) | Settings → Websites → Edit → Tracking code | in the head |
| [Cloudflare Web Analytics](https://developers.cloudflare.com/web-analytics/get-started/) | Web Analytics → Manage site | at the end of the body |
| [Google Analytics 4](https://support.google.com/analytics/answer/9304153) | Admin → Data streams → View tag instructions → Install manually | in the head |
| [Google Tag Manager](https://support.google.com/tagmanager/answer/14842164) | Admin → Install Google Tag Manager: two snippets | the first in the head, the second at the start of the body |

The snippet reaches the page exactly as you pasted it, where its tool says it goes. A card only checks that what you
pasted is a snippet, `<script>` tags and `<noscript>` if it has one, so a pasted ID or a stray tag is refused when
you save.

The public site changes pages without a full reload. Plausible, Umami and Cloudflare count those page changes on their
own. Fathom counts them once its script tag has `data-spa="auto"`, which its card reminds you to add. For Google
Analytics, keep **Enhanced measurement → Page changes based on browser history events** on, as it is by default; in
Tag Manager, a **History Change** trigger does the same.

Nibble sets no Content Security Policy for scripts, so each tool loads as it is. A site that adds its own policy has
to allow every tool's script and the address it sends visits to.

Cloudflare Web Analytics can be added once, since a page carries one beacon.

> [!TIP]
> A tool that isn't listed goes in [custom code](#2-custom-code), or a developer can add a card for it, as a set in
> the site's own `site/schema/globals/integrations.yml` whose snippet field is named `head`, `body_start` or
> `body_end` for where it goes.

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

Anyone whose role may edit the **Integrations** global, after entering their password again: what it holds runs on
every live page. That permission is separate from the other globals, and AI apps connected to the site can't reach
Integrations at all. See [Users and roles](../running/users-and-roles.md).

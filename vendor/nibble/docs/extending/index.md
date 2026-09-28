---
id: extending
title: Extending Nibble
description: The seams a site adds its own behaviour through, so an upgrade never conflicts with what you added — and
  when you do not need one at all.
order: 6
---

# Extending Nibble

Nibble has no plugin API yet. What it has is a set of **seams**: places a site can add behaviour of its own where
Nibble will keep finding it, so an upgrade never conflicts with what you added.

After reading this guide, you will know:

- Why editing Nibble's own files is the expensive way to change it.
- Which seam fits which job.
- When you do not need a seam at all.

## 1. Why seams

Everything under `vendor/nibble/` is Nibble's, and every release replaces it. Edit one of those files and it works —
until the next upgrade, which refuses to go ahead until you deal with it. Use a seam instead and the upgrade never
notices.

> [!IMPORTANT]
> `bin/rails nibble:check` warns about every file of Nibble's you have changed in place. That list is exactly what the
> next upgrade will refuse on. See
> [Upgrading](../running/upgrading.md#6-when-it-refuses-nibbles-files-changed-in-place).

## 2. Before you reach for one

Most things people want to add are a schema change, not code:

| You want | It is |
|---|---|
| a new kind of content | a [collection](../modelling/collections.md) |
| a new field | a line in a [blueprint](../modelling/blueprints.md) |
| a new block on landing pages | a set in a replicator, and a `.vue` file |
| a form that reaches your CRM | an [`api` delivery](../modelling/forms.md#5-sending-submissions-to-another-system) |
| to tell another system something changed | a webhook, set up in the Control Plane |

None of those needs a seam, and all of them are easier to live with. Reach for a seam when you need *behaviour*.

## 3. The seams

| Seam | For | Guide |
|---|---|---|
| `app/` | your own models, controllers, jobs and mailers | [Ruby hooks and events](hooks.md) |
| `config/initializers/*.rb` | your own Ruby, run at boot | [Ruby hooks and events](hooks.md) |
| load hooks `:nibble_entry`, `:nibble_term`, `:nibble_asset` | behaviour on a record, without reopening its class | [Ruby hooks and events](hooks.md) |
| `Nibble::Events.subscribe` | reacting after content changes | [Ruby hooks and events](hooks.md) |
| `Nibble::Forms.register_handler` | a form that does something Ruby has to do | [Ruby hooks and events](hooks.md) |
| **Webhooks**, in the Control Plane | telling another application | [Ruby hooks and events](hooks.md#6-webhooks) |
| `app/views/layouts/nibble/mailer.html.erb`, and each email's views | how the emails Nibble sends look, and what they say | [Emails](emails.md) |
| `site/cp/pages/<same path as ours>.vue` | replacing a Control Plane screen | [Customising the Control Plane](control-plane.md) |
| `site/cp/slots/*.vue` | the Control Plane's logo, sidebar and scripts | [Customising the Control Plane](control-plane.md) |
| `Gemfile` | gems of your own | [Ruby hooks and events](hooks.md#1-your-own-code) |
| `/api/v1/operations` and `/mcp` | changing content from another program or an AI agent, as a person | [The management API and MCP](management-api.md) |
| `site/agents/*.md` | telling agents your site's editorial rules | [The management API and MCP](management-api.md#6-telling-agents-about-the-site) |
| `bin/rails nibble:dev:mcp` | an agent building your theme or code | [Building with an agent](building-with-agents.md) |

## 4. What does not exist yet

A plugin API: something installable that registers fieldtypes, screens and widgets together, with its own version.
`bin/rails nibble:generate:plugin` refuses today, and says why.

The fieldtype contract and the form handler seam are the likely shape of it. If you are building something that wants
it, say so in an issue — the shape should come from a real case rather than a guess.

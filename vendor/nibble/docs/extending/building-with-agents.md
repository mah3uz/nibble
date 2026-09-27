---
id: extending-building-with-agents
title: Building with an agent
description: Give Claude Code, Codex or Cursor the tools to build a theme or extend a site properly — see a page's
  whole outcome, check, test, read logs and docs — and keep them out of Nibble's own files.
order: 5
---

# Building with an agent

When Tidewater's developer asks an agent to "add a reading time to the blog post page", the agent needs to know which
files are the site's, which view renders a post, what props it receives, whether the change worked and whether the
tests still pass. Nibble's developer tools answer each of those as data.

After reading this guide, you will know:

- How to connect an agent to the developer tools.
- What each tool does.
- Which skills come with Nibble.
- How Nibble keeps an agent out of its own files.

## 1. Connecting

```sh
bin/rails nibble:dev:setup
```

names the tools in `.mcp.json` for Claude Code and `.cursor/mcp.json` for Cursor, links Nibble's skills into
`.claude/skills/`, and stops Claude Code editing `vendor/nibble/`. For Codex, run `codex mcp add nibble-dev -- bin/rails nibble:dev:mcp`.

The tools run only in development, with code reloading on, over standard input and output — nothing listens on the
network — and they pick up each change the agent makes. `bin/rails nibble:dev:tool <name> '<json>'` runs any of them
from a terminal.

## 2. The tools

| Tool | Answers |
|---|---|
| `project_info` | versions, the active theme and whose it is, files taken over from Nibble, Nibble files changed in place |
| `where_is` | where a class, view, layout, component, Control Plane screen or schema item lives, whose it is, and how to change it |
| `schema_show` | the effective schema, and which layer — core, theme or site — each item comes from |
| `render` | everything one request produces: what it resolved to, the view, layout and sidecar that answered, props, cache tags, query count, status, and any error |
| `run_query_sidecar` | what a view's queries return |
| `check` | `nibble:check`'s findings, content the schema no longer covers, and Nibble files changed in place |
| `run_tests` | the site's tests, failures as data: test, file and line, message, backtrace |
| `lint` | RuboCop, ESLint or the Vue type checker, as findings with file and line |
| `logs`, `last_error` | what happened while the site ran: requests, Rails errors, server-rendering failures, failed jobs, Vite build errors and errors in the browser — read after a cursor |
| `search_docs`, `read_doc` | this documentation, for the version installed |
| `eject`, `generate` | take over a Control Plane screen; write a schema or theme stub |

> [!TIP]
> The loop that works: change a view, `render` a path that uses it, read the props and any error, then `run_tests`.

## 3. Skills

Three skills come with Nibble, in `vendor/nibble/skills/`, so each upgrade brings the ones written for it:

| Skill | For |
|---|---|
| `nibble-theming` | views, layouts, query sidecars and components, and checking them with `render` |
| `nibble-schema` | collections, blueprints and fields, and changing them without stranding content |
| `nibble-extending` | the site's own Ruby, Control Plane changes and events, without touching Nibble's files |

An agent loads one when the work calls for it. Claude Code finds them through the links `nibble:dev:setup` makes;
any agent that supports MCP's Skills extension gets them from the developer tools. A skill of your own in
`.claude/skills/` with the same name is left alone.

## 4. Keeping out of Nibble's files

An agent that edits `vendor/nibble/` makes the site impossible to upgrade. Three things stop it:

- `vendor/nibble/AGENTS.md` tells any agent working there that the files aren't its to change, and what to do instead.
- `nibble:dev:setup` denies Claude Code edits under `vendor/nibble/`.
- `check` and `project_info` report any Nibble file changed in place, and `nibble:check` fails on it.

`where_is` gives the right route for each case: edit the site's own file, define the same schema handle in
`site/schema/`, start a theme of your own, or eject a Control Plane screen.

## 5. Your conventions

A new site's `AGENTS.md` is yours: write down how you name things and what you want tested, and every agent reads
it. Claude Code reads it through `CLAUDE.md`.

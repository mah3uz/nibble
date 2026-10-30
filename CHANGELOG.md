# Changelog

What changed for a site running Nibble. Each release is a `##` heading, and inside it **What's new**, **What's
fixed**, **Changed** and **Security** are `###`.
Anything that needs you to act has an **Upgrade** note; releases without one are safe to take as they come. A
release whose database migrations cannot be undone says so in its entry, so you know the snapshot is the only way
back. The Control Plane shows these same notes, read from the feed the documentation site publishes, which is
generated from this file rather than written by hand.

Nibble is in beta: a release is meant to keep a working site working, and what it can't keep working is in an
**Upgrade** note. Themes pin the theme API (`nibble: '^1'` in `theme.yml`), not this number.

## Unreleased

> **One way to bring content in, wherever a page needs it.** The queries a view's sidecar runs now work for layouts,
> for the page's own linked records, and for a form's choices.

One database migration adds a column for the labels a submission was made with; it only adds, so it can be rolled
back, but the snapshot taken before an upgrade is the surest way back.

### What's new

- **A layout can query content.** `layouts/<name>.yml` is a sidecar like a view's, and its props reach every page
  using the layout, the 404, search and preview pages included, typed as `LayoutProps`. A layout that shares another's
  header takes its queries with `extends: default`. `nibble:check` refuses a layout query named like a view's or like
  a prop every page has.
- **A page brings its linked records along.** `page: { include: [loan] }` in a view's or layout's sidecar gives the
  page's relationship fields as whole records, so a view or layout reads the fields of what the page links to.
- **Child entries in a query.** `include: [children]` on a structured collection gives each entry its published
  children in tree order, enough for a menu of sections and their pages.
- **A form's choices can come from content.** A `select`, `radio`, `checkboxes` or `button_group` field on a form takes
  `options: { from: entries:<collection> }` (or `terms:`), with `value`, `label`, `where` and `sort`. Only published
  entries in the visitor's language are offered and accepted. `parent:` narrows one field's choices by the answer to
  another, through the tree or a relationship field, and the `@nibble` form helper hides choices that don't fit and
  clears one that stops fitting.
- **Submissions keep their choices readable.** Each choice's label is stored with the submission, so the Control
  Plane, emails and exports still show it after the option is renamed or removed; an encrypted field's labels are
  encrypted too.
- **Generated types follow `include`.** An included field is typed as the record it holds, and `children` as the
  collection's records.

### Changed

- crumbs lists topics in its footer from a layout query, and a post shows its author's bio.

## 0.24.0 — 2026-10-30 21:08 +0600

> **Change what a site already holds, safely.** A content migration can replace a shipped value where editors haven't
> changed it, and this release fixes the deploy of a site whose form emails a site setting.

It adds no database migrations.

### What's new

- **A content migration can change a value editors may have kept.** `set_value` replaces a stored value on every
  record and locale where it still equals `from`, or the keys of grid and replicator rows that match `where`. A value
  an editor has changed since, in the record or its draft, is left alone, a second run changes nothing, and `to` is
  checked against the field's own validation before anything runs.

### What's fixed

- **A site whose form emails a global's address builds again.** `bin/rails nibble:build` checked a `notify` recipient
  such as `{global.site.contact_email}` by asking the database for the global's columns, and an image build has no
  database, so `bin/kamal deploy` stopped with "Could not find table 'global_sets'". The check reads the schema alone
  now, and checks the global against the schema being checked rather than the running site's.
- **Events keep being delivered after a change is rolled back.** A change that published an event and was then rolled
  back, such as a preview, left its server thread believing a delivery was already on the way, so that thread
  queued none for its later changes; their webhooks, search updates and cache purges waited for another thread's
  delivery or a restart. A rollback clears that mark now.
- **A favicon can be an `.ico` file.** Site settings' Favicon field offers `.ico`, but the asset library refused to
  upload one, so a package setting an `.ico` favicon imported without it. `.ico` files upload now, and are served as
  they are.

## 0.23.0 — 2026-10-30 20:09 +0600

> **Menus that do more, and blocks you add instead of copy.** Menus gain headings, fields and kinds of their own,
> lists that fill themselves and show dates; a theme adds blocks to Nibble's standard ones; and crumbs, the theme
> every site starts from, uses all of it.

This release is mostly menus, blocks and the default theme. It adds no database migrations; its content migrations
for menus and global sets run only when a site writes them.

### What's new

- **`bin/rails nibble:schema:types --without-site`** writes a theme's types from Nibble's schema and the theme's
  alone, leaving out `site/schema`, so a theme you publish can be type-checked as it ships, whatever the site you
  develop it in changes.
- **Themes get the site's time zone as `site.time_zone`**, an IANA name such as `Australia/Sydney`, in every view's
  props, so a theme can date a post on the day it happened where the site is rather than in UTC.
- **crumbs uses what themes can do now.** It shows dates in the page's locale and the site's time zone, asks listing
  queries for only the fields it draws, sets `sizes` on its card and hero images, and counts each topic's articles. Its
  Main menu draws nested items, as a dropdown that works without JavaScript and an indented list on phones; its footer
  draws the Footer menu, falling back to Main while that is empty; its header shows the Site logo when one is set. Its
  404 page offers the menu, a search box and the latest articles; search results say whether a hit is an article or a
  page and where a page sits; the embed block plays YouTube and Vimeo videos in privacy-friendly players and links
  anything else; form fields sit side by side by their `width` hint; and the fallback taxonomy views show a term's
  description.
- **Menus can hold more than links.** A navigation can allow headings (`headings: true`), links to a global's
  address field (`globals:`) and to files (`assets: true`), and fields of its own on every item (`item_fields:`), such
  as a description or an icon; `entry_fields:` hands a theme chosen fields of the page an item links to. Any item can
  open in a new tab, be hidden, or show only between two dates, and cached pages change at each date. A menu that
  declares none of this behaves, stores and types exactly as before.
- **Mega menus, when a navigation asks for them.** `kinds:` declares item kinds of its own, such as a featured card
  with an image and a button, each saying whether it links and holds children. `queries:` lets an item list a
  collection's published pages — a page's children, or a term's entries, sorted, up to 50 — so a new page appears
  without editing the menu; any change to that collection clears the pages that show the menu, so keep it for small
  collections.
- **Each menu item tells a theme whether it is the current page** (`current`) or leads to it (`in_trail`), so themes
  stop working it out themselves, and `useNavigation('main')` is typed from the menu's schema: `@site/types` gains a
  `<Menu>NavigationItem` per menu that narrows on `kind`. Apps and agents are told each menu's item shape.
- **The menu editor** adds headings, site-setting and file links, Open in a new tab, Hidden, the menu's own fields and
  kinds, lists of pages, and show dates; items can be duplicated, collapsed and moved by keyboard as well as dragged
  between levels, and a refused save marks the item each problem is on.
- **Content packages carry every kind of menu item**, naming the pages, terms and files it links to by key. An
  existing package imports as before.
- **A theme or site adds blocks to Nibble's standard ones** with `add_sets` under a reference's `config:`, and leaves
  some out with `remove_sets`, instead of copying the whole list. `nibble:check` refuses an added block whose handle is
  taken or a removal of one that isn't there, and warns when a removed block still holds saved content.
- **Content migrations rename and delete menus and global sets**: `rename_navigation`, `delete_navigation`,
  `rename_global` and `delete_global`, in every locale and with their permissions. `nibble:check` warns about a menu
  stored for a navigation the schema no longer has, and names the migration that clears it.
- **crumbs uses all of it**: its header and footer mark the current page and section from the menu, open new-tab
  items in a new tab and say so to screen readers, and draw headings as dropdown titles and footer columns (crumbs'
  Footer menu allows headings and two levels); its pages offer a Latest posts block, added with `add_sets`.

### What's fixed

- **`nibble:check` accepts `messages.unique` on a field the form's `limits.unique` names.** It said the field had no
  rule for that message, though a repeated value shows it.
- **crumbs' contact form takes posts without JavaScript when it is paced.** It now sends the `_nibble_t` hidden
  input, so a form with `spam.min_seconds` no longer counts every no-JavaScript post as spam.
- **crumbs opens off-site menu items.** It drew them with Inertia's `Link`, which can't leave the site, so a menu item
  such as GitHub did nothing; it uses a plain link now, as the CTA block does for an off-site link.
- **crumbs' light or dark choice arrives with the page.** It is kept in the `nibble_theme` cookie, so a returning
  visitor doesn't see the other scheme first; a choice an earlier crumbs saved carries over.
- **crumbs loads its fonts from the page head**, not an `@import` that held up the stylesheet, and its footer no longer
  prints the year, which a cached page could show stale.
- **Renaming a collection keeps who may edit it.** `rename_collection` moves roles', connected apps' and Agent access
  permissions to the new handle, and `delete_collection` removes them; they stayed on the old handle, so the collection
  quietly disappeared for every editor who wasn't a superuser. `nibble:check` no longer stops an upgrade over a role
  naming a handle that a pending migration renames.
- **The menu editor offers only the levels a menu allows.** It offered one more than `max_depth`, which the save then
  refused, and a menu without `max_depth` is no longer held to three levels.
- **Re-importing a package doesn't count a menu as changed** because a save stores an item's field differently from
  how the package spells it.

### Changed

- **crumbs' starter contact form is paced instead of using a CAPTCHA.** `spam.min_seconds: 3` and `spam.max_links: 2`
  replace `captcha: true`, so a fresh install takes messages without keys. A page that shows the form is no longer kept
  in the page cache, since each visit needs a fresh timestamp.

**Upgrade:**

1. **A site that relied on crumbs' CAPTCHA keeps it with a form of its own.** Copy
   `vendor/nibble/themes/crumbs/schema/forms/contact.yml` to `site/schema/forms/contact.yml` and set
   `spam: { captcha: true }`.
2. **A theme that draws a paced form with its own markup adds the timestamp.** Add
   `<input v-if="form.timestamp" type="hidden" name="_nibble_t" :value="form.timestamp" />`, or posts without
   JavaScript are counted as spam.
3. **A site that renamed a collection before this release** re-ticks that collection's permissions under **Roles**,
   checks its row under **Agent access**, and reconnects apps that were granted it.

## 0.22.2 — 2026-10-30 05:17 +0600

### What's fixed

- **A site builds its assets again.** The rich text editor's character counter and placeholder, and the Control Plane's
  calendar, use packages that 0.22.0 didn't declare, so `bin/vite build` (and a deploy) could fail with `failed to
  resolve import "@tiptap/extensions"`. Both are declared now, and a test fails when Nibble's frontend imports a
  package it doesn't declare.

## 0.22.1 — 2026-10-30 05:00 +0600

### What's new

- **`bin/rails nibble:dev:setup --remove` undoes the setup.** It takes out the developer tools server, the `vendor/nibble/`
  rule and the skill links, leaves anything else in those files, and the setup chooser now asks again on an answer it
  can't read.

### Changed

- **A site's skill doesn't repeat "nibble" in its name.** A site called Nibble gets the skill `nibble`, one called
  Nibble Docs gets `nibble-docs`, and any other site keeps `nibble-<site name>`. In the folder where you use it, run
  `nibble disconnect <site>` and then `nibble connect <site>` (the `nibble` command 0.3.4 or later), which replaces the
  skill under its old name.

### What's fixed

- **The rich text guide names the link dialog's Site settings tab,** where it said Global.

## 0.22.0 — 2026-10-30 04:29 +0600

> **Forms that calculate, hold and report.** A public form can total a quote, open and close itself, catch spam and
> notify the right people, and its submissions are handled in the Control Plane like any other work.

This release is mostly forms and fields, and a plainer Control Plane. Four database migrations are added; they only
add tables and columns, so they can be rolled back, but the snapshot taken before an upgrade is the surest way back.

### What's new

- **Public forms can be handled, not just stored.** Each submission is **New** or **Handled**, can be marked unread,
  and carries internal notes, and the list takes bulk actions. A person's submissions can be exported or erased by
  email address, exports and deletes are recorded in the audit log, and the submissions of a form removed from the
  schema are purged after the retention period.
- **Form notifications need no code.** `notify` entries merge `{field.x}` and `{global.set.field}` into the subject
  and message, take recipients from a field or a global (`to: {field.email}`), and are routed with `if:`. Each email
  is recorded on the submission, and **Send notifications again** resends them.
- **A form can open, close and cap itself.** `limits:` takes `opens_at`, `closes_at`, `max_submissions` and `unique`
  (a value accepted once, such as a ticket code), with a `closed_message` shown when it is closed. A form's
  `submit_label` replaces the button text.
- **More ways to catch spam.** `spam.min_seconds` treats a submission sent too soon after the form was shown as spam,
  and `spam.max_links` catches text full of links. The rate limit now counts only accepted submissions, so refused
  posts no longer lock a real visitor out, and the refusal says how long to wait.
- **A form field can be encrypted.** `encrypt: true` stores the value encrypted, bound to its submission and field.
  Staff, exports, emails, deliveries and per-person search still read it.
- **Multi-step forms, saved forms and calculations.** `steps: true` turns sections into checked steps. `resume: true`
  adds **Save and finish later**, with a link emailed to the visitor. A `calculation` field is worked out on the
  server when the form is sent, with a live figure in the theme through `calculated()`.
- **Forms speak the visitor's language.** A multilingual site translates a form's text, Nibble's own form messages and
  the visitor's confirmation email.
- **Hidden and prefilled form fields.** A `hidden` field is filled from a fixed `value` or from the page's query
  string with `prefill`.
- **Themes get what they need to draw a form.** A form field arrives with its fieldtype settings, its resolved default
  and its conditions as rules to evaluate. `useNibbleForm` applies conditions, leaves out fields hidden by one,
  refills typed values after a refused post even without JavaScript, and gives ids, `aria-describedby`, an error list
  and focus targets. Crumbs' contact form draws every public fieldtype accessibly, with steps, calculations and the
  closed message.
- **Rich text can link to a global.** Choose a global field in the link dialog, or write
  `[Apply](global:site.apply_url)` through the API, and the link follows the global's address when the text renders.
- **Content migrations work on globals.** `rename_field` and `set_default` take a `global` in every locale, and the new
  `move_field` and `remove_field` carry values to another global or drop a field that left the schema, so nothing is
  stranded.
- **New fieldtypes.** `decimal`, `range`, `rating`, `time`, `color` and `button_group` work in blueprints and public
  forms, with Control Plane controls and crumbs inputs. `note` shows Markdown between a form's fields and stores
  nothing. Decimal, range and rating can be used in calculations.
- **Date-times can have a time zone.** `time_zone: Europe/London` (or `site`) reads the time as typed in that zone,
  stores the moment in UTC and shows it in that zone. A time the clocks skip is refused, and a repeated one takes its
  first occurrence.
- **Text can be validated by what it holds.** `input_type: email`, `url` or `tel` checks the value on save, in
  blueprints and on public forms. A toggle's `inline_label` can hold Markdown links, for a consent checkbox.
- **A field's `required` and `read_only` can take a condition.** The required marker shows only while the condition
  passes, and a hidden field keeps its stored value.
- **Read-only means read-only.** A value sent for a `read_only` field is kept as stored whoever saves, rows in grids
  and replicators by their `id`. Entry, term, global and asset writes through the API answer with an `ignored` list of
  the fields whose value was kept.
- **Apps see fuller field schemas.** The JSON Schema an app writes against describes length, format, range, step,
  option labels, read-only state, conditions and when a field is required.
- **`list_form_submissions` takes `since` and `q`,** searching as the Control Plane listing does.
- **`site/types.d.ts` types each form's values,** and a view's form prop uses them, so `values.topic` is typed.
  `useNibbleForm` takes that type; an untyped call is unchanged.
- **`computed:today` is a built-in default,** the current date in the site's time zone.
- **Blocks are easier to work with.** Undo a removed block or grid row from the notice that appears, move blocks and
  rows up and down from their menu, copy a block and paste it into any field with the same set, and use
  `collapse: accordion` to keep one block open at a time. Grids and blocks have a **Full screen** action.
- **Rich text options now do what the reference says.** `placeholder`, `character_limit` (with a counter),
  `toolbar_mode`, `smart_typography`, input and paste rules, `link_noopener`, `link_noreferrer`, `link_collections`
  (the link dialog's **Page** tab lists routed collections), `always_show_set_button`, `previews` and
  `inline_hard_breaks`.
- **Pickers have modes and can create.** `entries` and `terms` fields take `mode: auto | default | select | typeahead
  | stack`; `auto`, the default, is a dropdown for 25 or fewer choices. People allowed to create the item see
  **Create a new …** in the picker. `nibble:check` refuses an unknown mode.
- **Duplicate an entry** from the editor or the listing. A field's `duplicate` option decides what is copied; slug and
  `unique` fields are left out by default.
- **Entry listings sort and filter by field.** Field columns sort, and listed choice, toggle and date fields add
  filters. `sortable` and `filterable` turn them off or on per field.
- **Documentation covers more of the site.** A theming guide to forms, pages on what a view receives and on styling
  and the page shell, a **Reference** section listing every fieldtype option, validation rule and condition, and the
  forms guide split into declaring, delivery, spam and privacy, translation and a key reference. Tests fail when the
  code gains an option the pages miss.
- **Guides for the people who run a site.** Webhooks, the Utilities screens, every `nibble:check` message, every
  environment variable and task, the page cache and CDN, sign-in lockout and recovery, and administering from the
  Control Plane without a terminal.
- **`bin/rails nibble:dev:setup` asks which AI tools to set up** — Claude Code, Codex or Cursor, those found on this
  computer chosen by default — and writes only into the site's folder. `--tools claude,codex` answers without asking.
  Codex gets a project `.codex/config.toml` and the skills, like Claude Code.
- **The Connected apps screen shows `nibble connect <site>`,** which sets up Claude Code, Codex and Cursor in the
  folder it runs in, with the site's MCP server and skill. It needs the `nibble` command 0.3.0 or later.
- **Apps are told more about each field.** A field's description says when it is shown, required or read-only, and the
  bundled schema, theming and extending skills cover the new fieldtypes, forms and reference pages.
- **Guides for editors, and routes in.** Settings, categories and tags, the trash, your account and two-factor
  sign-in, and form submissions, with start-here routes by audience and every guide listed on the docs home.

### What's fixed

- **Crumbs ships a fallback `default` view,** and `nibble:check` warns when a collection's entries resolve to a view
  the theme lacks. A set without a view is a warning, since its blocks render nothing.
- **The 500 page gets the site's shared props,** falling back to empty ones if loading them fails.
- **Saving changes to a live entry no longer warns that someone published a newer version.** The warning now appears
  only when the entry really was published after those changes were started.
- **Publish works on a new entry,** creating and publishing it in one click, and a new entry in a collection that
  needs review offers **Submit for review**.
- **Apps are no longer told a field hidden by its condition isn't saved;** it keeps what's sent, and only its rules
  are skipped.
- **The Backups screen links to the restore section** of the backups guide.
- **The health check asks the page renderer on the configured port.**
- **`nibble:generate:form` writes `required: true`.**
- **Form emails show every fieldtype's value again.** Only a fieldtype with its own display formats a submitted value.
- **A form field's `messages` override the step error,** and a calculation's posted value is never kept in a saved
  form.

### Changed

- **Plainer wording in the Control Plane.** Page-builder sets are **blocks**, globals are **Site settings**, pending
  edits to a live page are a **Draft**, a taxonomy shows its own name, and link targets are filtered by **Type**.
  Statuses show their label (In review, not the stored key), error summaries name a field once by its label, and
  messages say what to do next in plain words.
- **History, the audit log and approvals say what happened.** They show field labels, readable values, titles and
  verbs, and an approval says what it does and changes. Signed-in devices have names.
- **The Control Plane formats numbers and dates in the site's locale,** the default one in `config/nibble.yml`. When
  that locale names only a language, such as `en`, the browser's region for it decides the style, so an Australian
  browser sees day/month/year and an American one month/day/year; a site that declares no locale follows the
  browser. Until now every Control Plane wrote Australian dates.
- **Default validation messages name the field once:** "Your name is required." rather than "The Your name field is
  required.". Their keys are unchanged, so a site's own `messages:` and translations still apply.
- **Date fields are compact** unless `full_width: true`, or the date-time has a `time_zone`.
- **Relationship fields with 25 or fewer choices show a dropdown** and offer **Create a new …**.
- **`nibble:check` reports more:** records holding a switched-off required toggle, saved text failing an email, URL or
  phone check, a picker mode it doesn't know, and a `link_collections` handle that names no collection.

### Security

- **CSV exports can't run formulas.** A cell that starts like a spreadsheet formula is written as text, in entry, term,
  submission and per-person exports.
- **Rich text links to other sites carry `rel="noopener"`** by default.
- **A resume link's token stays out of the request log,** and the personal data export of saved forms leaves it out.

**Upgrade:**

1. **A required toggle must be switched on, everywhere.** `required: true` on a `toggle` now means it has to be on:
   entries holding one switched off can't be published, and terms and globals can't be saved. `bin/rails nibble:check`
   lists them; fix them, or drop `required` if "off" is a valid answer.
2. **CSV exports put `'` before cells that look like formulas.** A script that parses an export sees `'=SUM(A1)`
   where it saw `=SUM(A1)`; strip a leading `'` if you read the files.
3. **Writes to a `read_only` field are now ignored** from the Control Plane, API tokens and MCP, and likewise for
   `visibility: read_only`. An integration that sets such a field must use an import, a content migration or a
   scheduled task, which are exempt, or you remove `read_only` from the field.
4. **Email, URL and phone `text` fields are checked on save.** A saved record whose value fails can't be saved until
   it is fixed; `bin/rails nibble:check` lists them. To check a phone number against your own pattern, use
   `validate: regex:`, which replaces the phone check.
5. **A rich text field with `character_limit` refuses longer text on save.** Content already over a newly set limit
   can't be saved until it is shortened.
6. **`to: {global…}` on a form notification** lets whoever edits that global choose where submissions go. Keep such a
   global to people you'd trust with the inbox.
7. **A custom theme must post `_nibble_t`** (a hidden input holding `form.timestamp`) when a form sets
   `spam.min_seconds`, or every submission is caught as spam. `useNibbleForm` and crumbs already do.
8. **`limits.unique` covers only submissions accepted after it's added.** Duplicates already stored are left alone.
9. **Rich text links to other sites now get `rel="noopener"`.** Set `link_noopener: false` on the field to keep the old
   output.
10. **Editors will notice:** date fields are compact unless `full_width: true` or zoned; grids and blocks have a
    **Full screen** action; relationship fields with 25 or fewer choices show a dropdown and offer **Create a new …**
    to people allowed to; entry listings gain filters for listed choice, toggle and date fields; and the new names
    (blocks, Site settings, Draft, Type).
11. **Four new database migrations** add form handling (handled state, notes, retention), encrypted submission fields,
    submission keys for `limits.unique` and saved forms (`form_partials`). `bin/rails nibble:upgrade` runs them. They
    only add tables and columns, so `bin/rails db:rollback` can undo them, which drops what they hold.
12. **`site/types.d.ts` gains form value types.** `bin/rails nibble:upgrade` regenerates it; commit the new file.
13. **AI apps you connected with `nibble` 0.2.0 were set up for your whole account,** so a site's tools and guide load
    in every project. Update `nibble` to 0.3.0, run `nibble disconnect <site>` once, then `nibble connect <site>` in
    the folder where you work on that site. If you ran `codex mcp add nibble-dev`, remove it with
    `codex mcp remove nibble-dev` and run `bin/rails nibble:dev:setup` again to choose your tools.

## 0.21.4 — 2026-10-29 21:30 +0600

### What's new

- **A field can say what it expects.** `messages: { regex: "Enter an Australian mobile number" }` on a blueprint or
  form field replaces the default text for that rule, as a string or per locale, on public forms, in the Control Plane
  and in API errors. `nibble:check` refuses a message for a rule the field doesn't have.
- **Number fields on forms reach the theme with `min`, `max` and `step`,** and crumbs draws them as number inputs. A
  public form refuses a value off the step, as the browser does; blueprint fields still treat `step` as a hint.
- **A submission caught as spam can be rescued.** Its values are kept (never its files) for `spam.retention_days`,
  30 by default. The submissions list shows **All but spam** and a **Spam** tab with its count, and **Not spam**
  stores the submission and sends its emails, deliveries and handler once, as if it had just arrived.

### Changed

- **Spam is deleted after `spam.retention_days`** (30 by default, or `retention_days` if shorter), including spam
  stored before this release, which holds no values.
- **`nibble:check` warns when a form's honeypot has a name autofill may fill in,** such as `website` or `email`,
  because a visitor's browser would then mark a real enquiry as spam.

## 0.21.3 — 2026-10-29 20:05 +0600

### What's new

- **A stopped upgrade can be finished.** When an upgrade fails after the new release is swapped in, fix what it stopped
  on and run `bin/rails nibble:upgrade --resume`: it carries on from installing gems, with the snapshot and the old
  release it already kept.

### What's fixed

- **An upgrade no longer stops when the new release generates different types.** It writes `site/types.d.ts` again
  right after the swap, so `nibble:check` no longer refuses it as out of date. Commit the new file with the upgrade.

  **Upgrade:** a site whose upgrade to 0.21.2 stopped at "generated types are out of date" finishes it from the site's
  root with `bin/rails nibble:schema:types`, `bin/rails nibble:prepare`, then
  `bin/rails nibble:upgrade:finish tmp/nibble-<the version you came from>`, before taking this release.
- **Pasted Markdown keeps its headings.** A `#` or `#####` heading pasted into a rich-text field became a paragraph
  with Tiptap 3.32; it now becomes the nearest heading the editor allows, h2 or h4.

### Changed

- **`bin/rails nibble:upgrade` refuses while an upgrade is unfinished,** and says how to finish it with `--resume` or go
  back, instead of starting over and replacing the old release kept as the way back.

### Security

- **Fewer packages with known advisories.** Vite, Vitest and Tiptap need releases with their fixes, and `shadcn-vue`,
  which only scaffolds components and pulled in most of the advisories, is no longer installed. A site's `npm audit`
  goes from 26 findings to 2 moderate ones in `@tailwindcss/typography`, which only reads Nibble's own stylesheets at
  build time.

## 0.21.2 — 2026-10-29 18:40 +0600

### What's new

- **A block's count can have a default.** `limit: { from: $set.count, default: 3 }` (and the same for
  `paginate.per_page`) uses the default while the editor's field is blank, as it is on a block saved before the field
  existed.

### What's fixed

- **CAPTCHAs are verified on a site that limits `outbound.allowed_hosts`.** The check went through the allowlist, so
  every submission was refused as a robot unless the provider's host was listed. The provider's verification address
  is fixed in Nibble, so it is called without being listed; a check that can't be made is now logged.
- **A term query with `counts` is typed with `entries_count`** in `site/types.d.ts`, so a view can show the count
  without a cast.

### Changed

- **A blank `limit: $set.<field>` shows at most 100,** the cap an editor's own number is held to, instead of the whole
  collection.

  **Upgrade:** a block whose count field is blank and whose collection has more than 100 entries now lists 100. Add a
  `default` to its sidecar's `limit` to choose another number.

## 0.21.1 — 2026-10-29 17:57 +0600

### What's new

- **Forms can be split into sections.** `sections: [{ display, instructions, fields }]` takes the place of `fields`,
  and the theme gets the groups as `sections` beside the flat `fields`; crumbs draws each as a numbered fieldset.
  Submissions, emails and API deliveries are unchanged.
- **Form fields carry `prepend` and `append`** to the theme, so an amount can show `$` before its input.
- **`offset` works with `paginate`,** so a featured post can sit above a paginated grid without repeating on page 2.
- **Term queries can count entries.** `counts: posts` on a `terms:` query gives each term `entries_count`, in one
  query.
- **`nibble:check` names records not at their route,** per collection and taxonomy, and `nibble:prepare`, which every
  deploy runs, moves them, including the terms of a taxonomy that has just been given a `route`.

### What's fixed

- **The page title, description, canonical link and robots tag appear once with SSR,** instead of twice until the page
  hydrated.
- **The 404 view gets its sidecar's data,** like any other view, instead of only `site` and `seo`.

### Changed

- **A form that asks for a CAPTCHA the site hasn't set up** gives the theme `captcha: { provider: null, site_key: null }`
  instead of `null`, so it can be told apart from a form without one. Its submissions are still refused.

  **Upgrade:** a theme that draws its own CAPTCHA widget whenever `form.captcha` is set should check
  `form.captcha.provider` instead. `useNibbleForm` already does.

## 0.21.0 — 2026-10-29 14:51 +0600

> **Approving an app's change makes it.** Each connection chooses whether to ask first, and its access can be changed
> after it is connected.

### What's new

- **Approving a change makes it.** When a connected app's change waits for approval, approving it in the Control Plane
  carries it out, as the app, and keeps the result; the app sends nothing again. Permissions are checked again at that
  moment, so a connection revoked or narrowed in the meantime fails instead of changing anything, and the person is
  told. Apps read the outcome with the new `get_approval` operation.
- **Each connection chooses whether to ask.** Connecting an app offers **Ask before live changes** (the default) or
  **Make changes without asking**, which needs your password. Under **Users → Agent access**, **Approvals** decides
  whether people may choose: **Each person chooses** or **Always ask**. An app signed in with a code always asks.
- **Approve or decline several at once,** with one password confirmation.
- **A connection's access can change after it's connected.** **Settings** on each connected app, under **Account →
  Connected apps** for your own and **Users → Agent access** for everyone's, changes its name, what it may do and
  whether it asks, without connecting again. An administrator's change never goes past what the app's person may do
  or what Agent access allows, is audited, and tells that person what changed and who changed it.
- **An app learns what it can't do and why.** `GET /api/v1/operations` lists the operations a connection can't use
  under `unavailable`, each with what it needs (such as "Assets: Write"), and calling one names that need.
- **Apps send files without base64.** `PUT /api/v1/uploads` takes a file's bytes, and `upload_asset` takes the upload
  it returns, or a `url` for the site to fetch. `create_upload` gives an MCP app the address to send a file to. A file
  waiting for approval is kept once, and the approval page shows it.
- **Markdown works in rich text at any depth,** including the rich text inside a page's blocks, in what apps write and
  what they read.
- **`describe_schema` lists each block's sets and their fields,** so an app can write blocks without reading an
  existing entry first.
- **A dry run warns about what it can't place:** a block type the field doesn't have, or an image whose asset doesn't
  exist.
- **Creating or changing an entry through the API returns `preview_url`,** the draft's preview in the Control Plane.
- **A connected app stays connected while it's used:** its sign-in ends 90 days after it was last used, not 90 days
  after it was connected.

### What's fixed

- **A missing theme says when `NIBBLE_THEME` chose it,** so a variable left in a shell or `.env` is easy to spot.

### Changed

- **The management API is version 2.** Rich text inside blocks is read as Markdown where it converts without loss,
  as top-level rich text already was.
- **An approval answer names its state:** `approval_pending`, `approval_denied`, `approval_expired` or
  `approval_mismatch`, instead of `approval_not_valid` for all four. A request repeated once its approval is done or
  declined asks again; a retry with the original `idempotency_key` gets the first answer.

  **Upgrade:** an app or script that reads nested rich text as editor JSON, or checks for `approval_not_valid`, needs
  updating. Nibble's own `nibble` command and MCP clients need nothing.

## 0.20.0 — 2026-10-29 03:37 +0600

> **A site runs its own chores on a schedule.** Fetch figures from an API, import a feed of jobs or call your own Ruby
> every few hours, and carry a package's images and files with its content.

### What's new

- **Scheduled tasks.** A task in `site/schema/tasks/` runs on a schedule such as `every 2 hours`, `at 5am every day`
  or a cron line, in the site's time zone. It can fetch from an API into a global, import a feed into a collection,
  call a URL, or run a Ruby handler. Tasks tick with the publishing schedule, so none needs a `config/recurring.yml`
  entry. Each slot runs once, a run never overlaps the one before, a failing API leaves stored values as they were,
  and administrators are told once when a task starts failing. An import changes only the entries it created, and
  leaves one alone while an editor has unpublished edits to it. A handler's context can update a global and call an
  API connection, which makes it the supported way for site code to do either. `nibble:check` checks every task, and
  **Utilities → Scheduled tasks** shows them, runs one now and pauses one.
- **A content package can carry its images and files** in an `assets/` folder beside `assets.yml`.
  `nibble:content:import` and the Control Plane's import upload the ones the site doesn't have before creating
  entries, and `--dry-run` lists them.
- **"Use this title as written" in the SEO field** gives a page's `<title>` and `og:title` exactly as the editor
  wrote them, without the title template.
- **"Leave out of the sitemap" in the SEO field** keeps an entry out of the sitemap while it stays indexable, and a
  collection's sitemap lists its index page, dated by its newest published entry.
- **A block's query can take how many items to show from the block** (`limit: $set.count`, and
  `paginate.per_page`), so an editor chooses. A blank value falls back to the default, and numbers are held between 1
  and 100.
- **`outbound.allow_private_networks`** lets a site call a CRM or API on your own machine or a private network while
  developing. It works in development and test only; production ignores it, and `nibble:check` reports it there.
- **An API connection's `base_url` can use `{config.x}` and `{secret.x}`,** so development, staging and production
  can call different addresses.
- **Back closes the open dialog or panel in the Control Plane,** innermost first, instead of leaving the page, and a
  dialog closed another way leaves no extra step in the browser's history.
- **The generated types have a union per collection and taxonomy** (`PagesEntry`, `TopicsTerm`), for a view that
  renders any of its blueprints.

### What's fixed

- **`nibble:content:import --dry-run` lists what it would create and update,** as the Control Plane's import does,
  instead of only saying the package is valid.
- **Adding a passkey no longer says it failed when it worked.** The dialog reported "Unexpected end of JSON input"
  after the passkey was saved; check your account's passkeys for one added this way.
- **A package's asset references match the stored filename as well as the one written,** so `Team Photo (1).JPG`
  finds the uploaded `team-photo-1.jpg`.
- **Development serves no cached pages unless `bin/rails dev:cache` is on,** so an edited view shows on the next
  request, and a change saved from a runner or a job appears.
- **A block's view no longer receives the block's `id` and `type`,** so the row's id no longer lands as an HTML `id`
  on the view's root element.
- **A site's type check covers its own code, not the bundled themes,** so `vue-tsc` passes on a site that doesn't
  use them.

  **Upgrade:** `tsconfig.app.json` is your site's; remove the two `vendor/nibble/themes/*` lines from its `include`.
- **The Trash shows a page at a time,** one kind at a time (entries, terms or assets), so something deleted beyond
  the first screen can still be restored.
- **Missing pages are paged and searchable by path,** instead of showing only the 100 most visited.
- **The notification bell loads older notifications** with Load more.
- **Sorting Users by a column descending works;** it always sorted ascending.

### Changed

- **Redirects are listed like Users:** a page at a time, searched by From and To, sorted by hits or last hit, and
  deleted in bulk, showing who added each (by hand, automatically or by an import) and when it was last used. Adding
  or editing one opens a dialog that keeps what you typed when a field is rejected, says what From and To accept,
  names each status ("Permanent (301)"), and suggests pages for To.
- **The share image is picked from the media library** and sized by the `og` preset, instead of typed as a URL.

  **Upgrade:** `bin/rails db:migrate` turns a share image that points at one of the site's assets into that asset
  and removes any other, printing each one so you can pick it again. This migration can't be undone; the snapshot is
  the way back.

### Security

- **A form with `captcha: true` refuses submissions while no CAPTCHA keys are set,** as the documentation says,
  instead of accepting every one. The visitor is told the form can't take submissions right now, and `nibble:check`
  warns about each such form.

  **Upgrade:** if a form uses a CAPTCHA, make sure its keys are under **Globals → Integrations** before you deploy.

## 0.19.2 — 2026-09-28 15:34 +0600

### Changed

- **An analytics card takes the tool's snippet as the tool gives it,** and the page gets that snippet unchanged, where
  the tool says it goes: the head for most, both of Tag Manager's parts, and the end of the body for Cloudflare. Each
  card says where the tool shows its snippet. A card checks only that what was pasted is a snippet, so a tool changing
  its snippet never stops Nibble accepting it. The Script tag card is gone, since custom code does the same, and so is
  `Nibble::Analytics.register`: a site adds a tool of its own as a set in its Integrations schema.

  **Upgrade:** analytics cards added on 0.19.1 hold values this release doesn't read. Before deploying, note each
  tool, then remove the cards: `bin/rails runner 'Nibble::Records::GlobalSet.where(handle: "integrations").find_each { |g| g.update_columns(data: g.data.except("analytics")) }'`,
  on Kamal through `kamal app exec --reuse`. After deploying, add each tool again and paste its snippet.
- **Integrations asks for your password again,** as users, roles and API tokens do, because what it holds runs on
  every live page.
- **Adding a block to a list that has one kind of block adds it straight away,** without a menu, and the menu of a
  list with several kinds closes once one is picked, shows each kind by name, and searches only a long list. A
  replicator can put its Add button in its section's header with `button_position: header`, and leave out the
  button on each block that adds one beneath it with `insert_below: false`; the Analytics and Custom code tabs do
  both.
- **A `code` field takes `rows`,** for how tall its editor starts.
- **Agent access lists connected apps in a sidebar,** one card per app with its access, its person, when and from
  where it was last used, when it expires, and Disconnect.

### What's fixed

- **A code field has a border like other inputs,** so in dark mode its help text no longer reads as part of it.

## 0.19.1 — 2026-09-28 14:34 +0600

### What's new

- **Analytics are cards: pick a tool, fill in what it needs, run as many as you like.** Plausible, Fathom, Umami,
  Cloudflare Web Analytics, Google Analytics 4, Google Tag Manager and a generic script tag each ask only for their own
  values, say whether they need consent, and pause from their card. Nibble writes each tool's tags as its vendor
  documents them, and tells the tools that need it to count page changes made without a reload. A site can add a
  tool of its own with `Nibble::Analytics.register`. The Analytics and custom code guide covers each tool.
- **Custom code is named snippets,** each placed in the head, at the start of the body or at the end, in the order of
  their cards, and paused from its card.
- **A replicator set can carry a `max`, a `badge` and an `icon`,** and `tab_count: true` shows how many blocks are
  switched on beside the tab's name.
- **A `code` fieldtype** edits HTML with line numbers and highlighting; custom code snippets use it.
- **Analytics cards show the tags they will write,** and explain a value in the wrong shape as it's typed. Field
  instructions can link to a page, so each card links to its vendor's install guide.

### What's fixed

- **Plausible's current `pa-` script tracks visits.** It only starts once an inline `plausible.init()` runs, which a
  script URL with data attributes never did; the Plausible card writes it.
- **Tag Manager's `<noscript>` frame opens the body,** where Google says it goes, rather than closing it.
- **The nightly backup runs without `DB_SNAPSHOT_BUCKET`,** keeping its copy on the server as the Backups screen
  says, instead of failing every night and keeping nothing. With the bucket set, it's uploaded to S3 as well.
- **Clearing a field stores nothing.** Every fieldtype stores a cleared value, whether empty text, an empty list or an
  empty grid, as no value at all, in entries, terms, globals, rows inside grids and replicators, and form submissions.
  A removed field someone emptied first no longer blocks a deploy as data that would be lost, and opening a form and
  saving it untouched writes nothing new. `false` and `0` are still values.
- **An emptied number field stores nothing,** rather than `0`.
- **Adding a passkey works.** The browser couldn't read the account id the server sent, and refused with an `atob`
  error.

### Changed

- **A field's `default` is what something new starts with,** and nothing else: a new entry, term, global or row,
  created from the Control Plane, the management API or MCP. An existing entry without a value no longer shows the
  default in its form, which the page never had either; fill those with the `set_default` content migration. Imports
  reproduce their source, so a field empty there stays empty.
- **A form's API delivery leaves out questions nobody answered** when it sends the whole submission, rather than
  sending them as empty strings. A `body` template renders them empty, as before.
- **The Integrations global's Analytics and Custom code tabs are replaced.** The GA4 and Tag Manager IDs, the script
  URL and attributes, and the head and body code fields are gone.

  **Upgrade:** before deploying this release, note what is under **Globals → Integrations → Analytics** and
  **Custom code**, then remove the old values from the running site. Emptying them in the Control Plane isn't enough:
  the release you are on stores an emptied field as an empty value, and `nibble:prepare` refuses to boot while a
  removed field holds one. Run, on Kamal through `kamal app exec --reuse`:
  `bin/rails runner 'Nibble::Records::GlobalSet.where(handle: "integrations").find_each { |g| g.update_columns(data: g.data.except("ga4_measurement_id", "gtm_container_id", "analytics_script_src", "analytics_script_attributes", "head_code", "body_code")) }'`.
  After deploying, add each tool back as a card, and each snippet as a snippet. Analytics are off between the two
  steps, for as long as the deploy takes. A site with its own
  `app/views/layouts/nibble.html.erb` adds `<%= Nibble::Integrations.body_start_html(@nibble_integrations) if
  @nibble_integrations %>` straight after `<body>`.
- **`install.sh` installs the `nibble` command and hands over to `nibble new`,** so there is one way to start a
  site, on Linux and macOS alike. It says how to get anything missing — mise for Ruby and Node, which systems package
  too old, and Homebrew, apt or pacman for the rest — and checks Ruby and Node against what the release needs before
  installing anything.

## 0.19.0 — 2026-09-28 02:01 +0600

> **AI apps work on a site as the people who connect them.** Claude, ChatGPT, Codex and Cursor connect over MCP,
> and the `nibble` command from a terminal. None can do more than the person it acts for, and an app waits for that
> person before anything goes live.

### What's new

- **AI apps can work on a site as the people who connect them.** An administrator turns on **Agent access** under
  Users, and chooses what apps may touch area by area — reading content and writing entry drafts to begin with.
  People then connect Claude, ChatGPT, Codex, Cursor or anything that speaks MCP at `/mcp`, sign in on the site, and
  choose what the app may do: read, write drafts, everything their role allows, or area by area. An app can never do
  more than its person, and whatever this page, the person's roles or the connection allow — the smallest of the
  three — is checked on every request.

  **Upgrade:** a site that sets `outbound.allowed_hosts` adds `claude.ai` to it before anyone connects Claude Code,
  whose description of itself the site fetches from there.
- **Publishing, trashing and live changes through an app wait for approval.** The person the app acts for sees exactly
  what would change, with a warning if it links to another site, and approves it once.
- **Connected apps** in the account menu lists each app, when it was last used, and pending approvals, and makes
  tokens for scripts. Revisions and the audit log say which app a change came through.
- **The management API** at `/api/v1/operations`: every operation an app can take, with its arguments as JSON Schema, a dry run,
  retries that don't repeat a change, `lock_version` so nobody's edit is overwritten, rich text as Markdown, and
  errors that say what to do next. Every answer carries its contract number, `Nibble::MANAGEMENT_API_VERSION`, so a
  client can tell whether it or the site needs upgrading.
- **The `nibble` command-line tool,** released on its own from
  [mah3uz/nibble-cli](https://github.com/mah3uz/nibble-cli): start a site, run its tasks as `nibble check`, sign in
  to any number of sites and accounts to work on their content from a terminal or an agent, and complete all of it
  in bash, zsh, fish and PowerShell. Install it with
  `curl -LsSf https://github.com/mah3uz/nibble-cli/releases/latest/download/nibble-cli-installer.sh | sh`.
- **A guide for agents,** written from the schema and the site's own notes in `site/agents/*.md`, served over MCP as a
  skill through its Skills extension, and installable as one.
- **Developer tools for agents building a site:** `bin/rails nibble:dev:mcp` renders a path and shows what answered it
  and its props, checks, runs tests with failures as data, lints, reads the development log and searches the docs;
  `bin/rails nibble:dev:setup` connects Claude Code, Cursor and Codex and keeps them out of `vendor/nibble/`.
- **Skills for building a site:** `nibble-theming`, `nibble-schema` and `nibble-extending` ship in
  `vendor/nibble/skills/`, served by the developer tools and linked into `.claude/skills/` by `nibble:dev:setup`.
- **The documentation ships with each release,** in `vendor/nibble/docs`.
- **New sites get an `AGENTS.md`,** which their `CLAUDE.md` imports.

### Changed

- **`nibble:assets:purge_unused` is now `nibble:cleanup:assets`, and `nibble:search:rebuild` is now `nibble:reindex`.**

  **Upgrade:** use the new names in scripts and deploy hooks.
- **Every change to content names who is making it.** `Nibble::Lifecycle.call` requires `actor:` — a user, a
  `Nibble::Principal`, or `Nibble::Principal.system` for jobs and imports — and checks that actor's permissions.

  **Upgrade:** Ruby of your own that calls `Nibble::Lifecycle.call` or `Nibble::Assets::Upload.call` passes an
  `actor:`.
- **API tokens only read.** The `manage:<collection>` scope is gone; changes go through the management API as a
  person.

  **Upgrade:** a token that had the scope keeps reading but can no longer write. A script that wrote through it
  uses a token made under **Connected apps** instead, with the management API.

### What's fixed

- **Approving or rejecting a review needs the approve permission,** as the editor's buttons already assumed; it had
  asked for the publish permission instead.

### Security

- **Navigation links and link fields refuse `javascript:` and `data:` addresses,** which a theme would have put into
  a page as a link that runs script.
- **Failed sign-ins to the content API are limited per address,** where each made-up token had its own allowance.
- **The content API's route lookup answers only for collections the API serves.** It resolved an address in any
  collection, so a token could learn the titles of entries the API otherwise keeps back.

## 0.18.3 — 2026-09-27 04:51 +0600

### What's fixed

- **Following a link to a cached page no longer opens Inertia's error dialog.** A page served from the page cache
  left out the `X-Inertia` header, so every click after the first showed its JSON in a modal instead of the page.
- **A partial reload is no longer cached as the whole page.** An infinite-scroll fetch could be stored in place of
  the page and served to the next visit with most of its props missing.

## 0.18.2 — 2026-09-27 03:56 +0600

### What's fixed

- **Crumbs highlights Vue and ERB code blocks.** A `vue` block colours its template, its script (as TypeScript with
  `lang="ts"`) and its styles, and an `erb` block its HTML and Ruby, where both showed as plain text.
- **The Control Plane knows Vue and ERB too.** A rich text code block can be set to either, and a Markdown field's
  preview colours them.
- **An entry with unpublished changes opens in the editor again.** So did its revisions and the dashboard's drafts
  list, which all failed with an error.
- **`delete_collection` removes the entries' drafts, revisions and relationships too**, as documented, where it
  left them behind.

## 0.18.1 — 2026-09-26 21:35 +0600

### Changed

- **Nibble's database migrations are one per table,** each creating its table as it is now, with its indexes and
  foreign keys. They keep the versions the tables were first created with, so a database already on 0.18.0 has
  nothing to run.

  **Upgrade:** a database from before 0.18.0 has to be created afresh, then its content imported.

## 0.18.0 — 2026-09-26 20:41 +0600

### What's fixed

- **The focal point editor is readable on any image, in light and dark.** Crops of many shapes fill the screen, and
  a column beside them holds the image, with a marker that shows on light and dark pictures alike (drag it, click, or
  use the arrow keys), and a zoom slider that follows the pointer.
- **Cropping starts with a selection in the middle of the image,** so it's clear at once what to drag. Everything
  outside it is dimmed, and the rule-of-thirds guides and handles show on light images too.
- **Reupload asks first.** It offers only files of the asset's kind, says which file takes its place, whether its
  extension changes, and that the current file can't be brought back, then shows the upload's progress.
- **Replace says what it did.** Its picker names the asset being replaced, choosing that same asset explains why
  nothing happens, and afterwards it reports how many places changed, or that nothing used the asset. When some
  can't be changed, it names them instead of "Request failed", and keeps the original.
- **The asset editor has a Close button beside Save,** and a click on the backdrop no longer closes it, so a stray
  click can't throw away an edit.
- **Live Preview updates in place as you type,** keeping its scroll position, instead of reloading blank each time. A
  theme's layout needs `PreviewBar` for this; without it the preview reloads as before.
- **A preview is marked with a Preview ribbon** across the top corner, which pulses while a change applies.
- **The dashboard's At a glance tiles show a count and its period,** "Last 30 days", without a comparison that read
  as "0 the 30 before".

### Changed

- **Rails' settings are all in a site's own files.** Nibble keeps none of its own: storage, mail delivery, the job
  schedule, Inertia, passkeys and the content security policy are written into `config/` at install, each under a
  `# Nibble:` comment that says why, and the time zone is Rails' `config.time_zone` in `config/application.rb`
  rather than a key in `config/nibble.yml`. In production, Nibble names a job missing from `config/recurring.yml`,
  or passkeys that don't allow the site's URL, at boot and in `nibble:check`.
- **Uploaded files are served from `/media/:uuid/…`,** and Rails' asset pipeline has `/assets` back.
- **`/up` is the site's route,** in `config/routes.rb` as Rails writes it, and the Active Storage migration is in
  the site's `db/migrate/`.
- **The control panel is the Control Plane, at `/cp`.** Every screen, sign-in and password reset moved from
  `/admin` to `/cp`; its controllers are `Nibble::Cp::`, its screens `vendor/nibble/frontend/nibble-cp/pages/cp/`,
  and a screen a site replaces lives at `site/cp/pages/cp/<same path>.vue`. `/admin` is no longer reserved.

  **Upgrade:** move any `site/cp/pages/admin/` screens to `site/cp/pages/cp/`, and update bookmarks.
- **Nibble holds none of the names Rails generates.** Its base classes, users, roles, sessions, sign-in and mailers
  are `Nibble::` (`Nibble::User`, `Nibble::ApplicationController`, `Nibble::PasswordsMailer`…), its identity tables
  are `nibble_users`, `nibble_sessions` and the rest, and its migrations are named `Nibble…`, and its sign-in cookie is `nibble_session_id`, so a site can
  run `bin/rails generate authentication` for accounts of its own. A new site starts with Rails' own
  `ApplicationController`, `ApplicationRecord`, layouts and PWA views. Email layouts and views a site replaces live at
  `app/views/layouts/nibble/mailer.*` and `app/views/nibble/<mailer>/`.

  **Upgrade:** run `bin/rails db:migrate`; everyone signs in again once. Move `app/views/layouts/mailer.*` and any
  email views you replaced under `nibble/`, then run `bin/rails nibble:install --only=app/` to write the base classes
  a site doesn't have yet.
- **The Control Plane uploads through its own route,** and Rails' public direct-upload endpoint, which takes
  uploads from anyone, is closed.

  **Upgrade:** take the offered `config/environments/production.rb`, `config/recurring.yml`, `config/routes.rb` and
  `config/initializers/content_security_policy.rb`. Write the files a site doesn't have yet with
  `bin/rails nibble:install --only=config/initializers/` and `bin/rails nibble:install --only=db/migrate/`. Move `time_zone` from `config/nibble.yml` to
  `config.time_zone` in `config/application.rb`.

### Security

- **An idle Control Plane session ends on the server.** After `session.idle_minutes` without activity (120 by default,
  in `config/nibble.yml`) the session is gone, so reloading the page asks for sign-in; before, the lock lived only in
  the browser. A minute before, a warning offers to extend it, and afterwards a dialog signs back in, with the
  two-factor code when it's on, without leaving the page.

  **Upgrade:** run `bin/rails db:migrate`.

## 0.17.0 — 2026-09-25 03:24 +0600

### What's new

- **Updates shows ten releases at a time,** with **Load more** for the next ten, which light up for a moment as they
  arrive. The list of releases is read a page at a time, and only as far as the release a site runs.
- **A paginated query can scroll.** `paginate: { scroll: true }` makes each page append to the last, for Inertia's
  `InfiniteScroll`.
- **Publishing a dated entry with no publish date publishes it now.** The date is stamped at that moment, as it
  already was for undated collections, instead of refusing until one is typed in.
- **Publish changes can skip its message.** The arrow beside the button offers **Ask for a message** or **Publish
  straight away**, remembered per person like the choice after saving.
- **An entry can leave search.** Every entry of a searched collection has an **Include in search** toggle in its
  sidebar, on unless someone turns it off; a page written as a file says `search: false` in its front matter. A
  blueprint with its own `search` field keeps it, and gets no toggle.
- **A search query can narrow by collection.** `where: { collection: docs }` (or `in:` a list, or `$params.section`)
  on a `search:` source searches part of an index, so one index serves a site-wide search and a docs-only one.
- **A query can ask for a record's `parent`,** its title and address, so a search result can say which section it
  sits in. It is looked up only when `fields` names it.
- **A new site lints and formats what it owns.** `npm run lint` runs ESLint over its themes and the screens it
  ejected, including the rule that a theme imports only `@nibble`, `@theme`, relative paths and its own
  dependencies; `npm run format` and `npm run format:check` run Prettier in Nibble's style.
- **Every email has a heading, and a button when there is something to do.** Invitations, password resets, form
  submissions and notifications are rewritten for the person reading them, and drawn in one layout that styles plain
  HTML. A site restyles them all with its own `app/views/layouts/mailer.html.erb`; the **Emails** guide lists what
  each one uses. A form submission says to reply only when a reply reaches the visitor.

### What's fixed

- **Search snippets read as text,** not Markdown: `**`, links and image syntax no longer show around the match.
- **A page written as a file is indexed once.** Its words were stored twice, which ranked it above an entry saying
  the same thing.
- **A view that asks for `parent` type-checks.** The generated types picked it from the record, which has no such
  key, so `site/types.d.ts` failed to compile; it is typed as `ParentSummary` now.
- **A theme from `nibble:generate:theme` passes the format check,** starting with its `theme.yml`.
- **`nibble:check` no longer reports a sidebar taxonomy or the search toggle as removed.** Both are kept on an entry
  beside its blueprint, and the check only knew the blueprint's own fields.
- **The generated types follow the theme a development server renders,** written as it starts, so an editor checks a
  theme against its own schema rather than whichever theme wrote the types last.
- **A site's `.gitignore` keeps out `vendor/nibble/Gemfile.lock`,** which some editors write beside Nibble's `Gemfile`.
  **Upgrade:** accept the `.gitignore` the upgrade offers.

### Changed

One change waits for `load_defaults: "0.17.0"`:

- **An index is made of the collections and taxonomies that name it,** with `search: <index>` in their own files.
  `search.yml` keeps each index's settings, such as `fields`; its `collections` and `taxonomies` lists are no longer
  read, and `bin/rails nibble:check` reports one that is still there. Taxonomies accept `search:` from this release.

**Upgrade:** to lint an existing site, copy `eslint.config.js` and `prettier.config.js` from
`vendor/nibble/templates/` into the site's root, and the `lint`, `format` and `format:check` scripts from
`vendor/nibble/templates/package.json.erb` into its `package.json`. The search index gains a column, so this release
recreates it, and `nibble:prepare` rebuilds it on the deploy that follows. Before raising `load_defaults` to
`"0.17.0"`, give every collection and taxonomy listed in your `search.yml` a `search: <index>` key of its own, and
remove the lists.

## 0.16.1 — 2026-09-24 04:53 +0600

### What's fixed

- **Installing with `--defaults` sets up the database,** as installing with questions does; it still leaves the
  administrator and the starter content to you. `bin/rails nibble:check`, the step the installer names next, crashed
  on the empty database it left. It now says when a database isn't set up and what to run, instead of crashing.

## 0.16.0 — 2026-09-24 04:39 +0600

> **Installed and upgraded as one folder.** Nibble lives in `vendor/nibble` and loads as a Rails engine; an upgrade
> replaces that folder and leaves the rest to the site.

### What's new

- **`bin/rails nibble:version` prints the release a site runs,** and says so when the install record in
  `config/nibble.yml` names another, as an upgrade that didn't finish leaves it. It answers without booting the site.
- **`bin/rails nibble` lists every Nibble command,** the grouped ones (`nibble:admin:*`, `nibble:schema:*` and the
  rest) included, with their full descriptions, under a header naming the release, the site's install record, its
  theme, the release whose behaviour it has switched on (`load_defaults`), the Ruby, Rails and Node it runs on, and the
  theme, schema and content format versions.

### What's fixed

- **The release feed carries every release,** not the latest 25, so the oldest releases keep their notes and their
  pages on the documentation site.
- **The asset build bundles the theme `NIBBLE_THEME` names,** as the server renders it. The build read
  `config/nibble.yml` first and the server read the environment first, so a site choosing its theme by environment
  served one theme's pages with another's assets. An image build takes the theme as the `NIBBLE_THEME` build argument.
  **Upgrade:** if your theme comes from `NIBBLE_THEME`, re-render `Dockerfile` when the upgrade offers it and pass the
  theme under `builder: args:` in `config/deploy.yml`.
- **Tests follow `config/nibble.yml`,** whatever `NIBBLE_THEME` a shell exports for running the site.
- **`bin/dev` renders pages on the server with the theme you are working on.** It rendered them with the last
  production build in `public/vite-ssr` instead, whichever theme that was built for, so a view that build lacked failed
  with "Page not found" and the rest showed stale markup until the browser replaced it. Server rendering now goes
  through the Vite dev server whenever it is running.

### Changed

- **Nibble lives in `vendor/nibble/`.** What was under `lib/nibble/`, `lib/commands/` and `lib/middleware/` moved
  there, and loads as a Rails engine: the `Gemfile` evaluates `vendor/nibble/Gemfile`. `config/application.rb` is
  plain Rails, `config/initializers/nibble.rb` is gone, and `lib/` is yours. Ejected screens are copied from
  `vendor/nibble/frontend/`.
  **Upgrade:** re-render `Dockerfile` when the upgrade offers it — the old one copies `vendor/` in a way that no
  longer installs Nibble's gems.
- **Everything of a site's own that Nibble reads lives in `site/`.** `schema/` is `site/schema/`, `content/` is
  `site/content/`, a site's theme is `site/themes/<name>/`, and control panel overrides are `site/cp/pages/` and
  `site/cp/slots/`. `crumbs` ships in `vendor/nibble/themes/` and is used from there unless `site/themes/crumbs/`
  exists; `nibble:generate:theme` copies it into `site/themes/`.
  **Upgrade:** `git mv schema site/schema`, `git mv content site/content`, `git mv site/pages site/cp/pages`,
  `git mv site/slots site/cp/slots`, and `git mv themes/<yours> site/themes/<yours>` for a theme of your own.
- **Generated types are `site/types.d.ts`,** imported as `@site/types`, rather than a file inside the active theme,
  so a theme that ships with Nibble is never written to.
  **Upgrade:** in your theme, replace imports from `'../.nibble/types'` (at any depth) with `'@site/types'`, delete
  its `.nibble/` folder and run `bin/rails nibble:schema:types`.
- **What Nibble needs from Rails' configuration comes with Nibble.** Its initializers (Inertia, WebAuthn, the
  `media` inflection, the assets prefix, the baseline content security policy) and its production settings (storage
  service, Solid Cache and Solid Queue, mail from `SITE_URL` and SMTP) are part of the engine, and its recurring jobs
  are read from `vendor/nibble/config/recurring.yml`. A site's own `config/` holds Rails' defaults, which it can
  change and which win over Nibble's.
  **Upgrade:** re-render `CLAUDE.md` when the upgrade offers it. If you changed any of the moved initializers, put
  your change in an initializer of your own.
- **Taking a release is `bin/rails nibble:upgrade`; bringing a database up to it is `bin/rails nibble:prepare`.** The
  first was `bin/nibble-upgrade`, a script beside yours; it is now a command that ships with Nibble. The second was
  called `nibble:upgrade`, and is named after Rails' `db:prepare`, which it stands in for when a server starts.
  **Upgrade:** in `bin/docker-entrypoint`, or wherever your deploy runs it, change `nibble:upgrade` to
  `nibble:prepare`, and take releases from now on with `bin/rails nibble:upgrade`.
- **A site is installed from a release, not a clone.** `curl -fsSL nibble.ink/install.sh | bash` asks for the site's
  name and makes its folder from it, downloads the release's archive, checks it against the published checksum,
  unpacks it into `vendor/nibble` and writes every other file from its templates, starting from the gem and npm
  versions that release was tested with. It works from any shell, fish included, and no longer needs `git`.
- **An upgrade replaces `vendor/nibble` with the next release.** `bin/rails nibble:upgrade` downloads the release
  and checks it against its published checksum, then hands over to that release's own upgrader, so a fix to upgrading
  applies in the release that ships it. It refuses if Nibble's files were changed in place (eject what you need to
  change), checks the release's Ruby, Node and theme requirements, snapshots the database, swaps the folders (the
  old one stays in `tmp/`), migrates, offers the site files whose templates moved on and reports ejected screens whose
  originals changed. It no longer needs git, and no longer merges anything.
  **Upgrade:** a site installed by cloning has no `vendor/nibble/MANIFEST`, so it can't take releases this way.
  Install a fresh site from this release and move your `site/`, `app/`, `db/migrate` and settings into it.
- **A new site's credentials include a `secret_key_base`.** Without one, production refused to boot.
  **Upgrade:** if `bin/rails runner 'p Rails.application.credentials.secret_key_base.present?'` prints `false`, add
  `secret_key_base: <the output of bin/rails secret>` with `bin/rails credentials:edit`.
- **Installing with `--defaults` records the answers it used,** so later upgrades can offer the files rendered from
  them.
- **A site's own Ruby and tests live where Rails puts them.** `site/initializers/` and `site/test/` are gone, and so is
  `Gemfile.local`: a site's `config/initializers/`, `test/` and `Gemfile` are its own now, and a new site starts with
  Rails' `test/test_helper.rb`. The notes that were in `site/schema/README.md` and `site/content/README.md` are in
  `site/README.md`.
  **Upgrade:** move `site/initializers/*.rb` into `config/initializers/`, `site/test/` into `test/`, and the gems in
  `Gemfile.local` into `Gemfile`.
- **Nibble's files changed in place are found by checksum.** `bin/rails nibble:check` compares `vendor/nibble` with
  the release's `MANIFEST` and names any file changed there, which the next upgrade would refuse to replace. The
  install record no longer holds a git commit, and nothing in Nibble needs git.
- **Nibble's record of a site lives at the end of `config/nibble.yml`,** below a line that says so: the release it is
  on, the install's answers and what it ejected. Only that part is ever rewritten, so your settings and comments
  above it stay as you wrote them. `.nibble/` is gone.
  **Upgrade:** add `# Written by Nibble from here to the end of the file. Your settings go above this line.` as the
  last line of `config/nibble.yml`; under it, `install:` with the keys of `.nibble/install.yml` indented beneath, then
  the `ejected:` section of `.nibble/ejected.yml` if you have one. Then delete `.nibble/`.

## 0.15.0 — 2026-09-23 21:11 +0600

### What's fixed

- **A menu built from files is read-only in the control panel.** It opened as an empty menu with Add link and
  Save, and whatever was saved there was read by nothing — the site builds that menu from the folders. The screen
  now lists the folders' tree and names the folder.
- **Pages written as files are searchable without a manual rebuild.** They publish no events, so they reached search
  only through `nibble:search:rebuild`. Every `nibble:upgrade` — so every deploy — now indexes them, and so does
  each change in development.
- **Development notices changes under `content/`.** An edited page or a replaced image was only picked up when Rails
  happened to reload code; the folder is now checked on every request, as the schema is.
- **A new view, block or control panel screen appears without restarting `bin/dev`.** The theme and `site/` sit
  outside Vite's root, so files added there stayed invisible until a restart.
- **The theme's types keep up by themselves.** `nibble:build` writes them before checking them, instead of refusing
  the stale file it was about to regenerate, and in development they are rewritten when a blueprint or a view's
  query changes.
- **The dashboard counts a folder's pages**, rather than showing a collection written as files as empty.
- **Missing pages is in the sidebar**, under Redirects. The screen existed, but nothing led to it.
- **A page title wraps instead of being cut off** beside the editor's actions on a narrow screen.

### Changed

Three fixes change what a site would notice, so they wait for `load_defaults: "0.15.0"`:

- **A field marked `api: false` stays out of the Content API**, in expanded relations and globals too. Until now the
  option only reached the generated types.
- **A collection's `search:` key decides its search index.** `search: <index>` joins that index and `search: false`
  leaves every index, read together with `search.yml`. Until now the key was accepted and ignored.
- **A changed route moves entries on the next deploy.** `nibble:upgrade` moves every entry and term whose address no
  longer matches its route, children after their parents, with a 301 from each live one. Until now each one moved
  only when it was next saved.

**Upgrade:** raise `load_defaults` to `"0.15.0"` in `config/nibble.yml` when you are ready. Check first that
`search.yml` and your collections' `search:` keys agree, since a collection that says `search: site` but is missing
from `search.yml` becomes searchable. After a route change, the deploy that follows records a redirect for each live
entry it moves.

## 0.14.7 — 2026-09-23 18:05 +0600

### What's fixed

- **A collection written as files shows its pages in the control panel.** The listing, the tree and the
  calendar read records, and a folder has none, so the collection looked empty while it served every page. They
  read the folder now: each page opens with its fields locked and names the file it is written in, and nothing
  offers to create, publish, move or trash one.

## 0.14.6 — 2026-09-23 03:42 +0600

### What's fixed

- **`where` and `not` narrow a folder-backed collection.** They were built into SQL and so applied only to
  records: a query over a folder dropped them without a word, and the view got everything it asked to filter
  out. They are answered against the pages now, with the same operators. A filter that reads a relation is
  refused rather than ignored — a folder has no relations to read.
- **The control panel stops offering to write into a folder.** A collection written as files refused a save
  but still let you start a new entry, create one and trash one — rows that answer to nobody, since the folder
  is what serves. Every way of writing to such a collection is refused now; opening one to read it is not.
- **A blueprint of a folder-backed collection counts its pages.** The blueprint listing counted records, so a
  collection served from files read as empty however many pages it had.


## 0.14.5 — 2026-09-23 02:34 +0600

### What's fixed

- **A collection served from files is no longer measured against the rows it left behind.** Turning one into
  a folder leaves its old records in place, read by nothing — but `nibble:check` still held the schema to
  them, so removing a field from the blueprint stranded rows nobody serves and stopped the site booting. The
  advice it gave could not be taken either: no migration operation empties a collection the schema still has.
- **A refused release leaves the tree as it found it.** `bin/nibble-release` writes the version and the
  changelog heading before running the checks, so a release that failed them left both files modified with
  nothing committed or tagged — and the next attempt refused, because `Unreleased` had already been emptied.
  It now puts both back on any exit that does not reach the commit.


## 0.14.4 — 2026-09-23 02:19 +0600

### What's fixed

- **A folder-backed collection sorts on `published_at` and `position` again.** Both are the page's own —
  one parsed into an instant, the other read from `order:` in the frontmatter — and the sort was looking for
  them among the frontmatter fields, where neither is. A collection ordered by either got whatever order the
  files happened to be read in. Sorting on a date now compares instants, so pages written in different
  offsets fall in the right order rather than in alphabetical order of their text.


## 0.14.3 — 2026-09-23 02:05 +0600

### What's fixed

- **Every page of a folder-backed collection renders again.** Its navigation tree left `children` off any
  link that had none, while the tree built from records always carries one — so a theme walking the tree,
  as the `Link` type says it may, threw on the first leaf and the page came back blank below its header.
- **A collection ordered on a number is ordered by the number.** A folder of files compared the field as
  text, where `"20"` comes before `"9"`, so any list with more than nine ranked pages came out shuffled —
  most visibly the release notes, which ran 0.14.2, 0.14.1, then jumped to 0.9.1 and left the newest
  releases scattered below the oldest.
- **A release's notes carry the time it was cut, back to the first one.** The nineteen releases that
  predate recorded times take theirs from their own tag's commit, so every entry is a real instant rather
  than an implied midnight. No release's date changed.


## 0.14.2 — 2026-09-23 01:36 +0600

### Changed

- **Nibble no longer picks a site's time zone.** It ran on Australian time wherever in the world a site was,
  set in a file a site cannot own. `config/nibble.yml` takes a `time_zone` now — an IANA name such as
  `Asia/Dhaka` — and with nothing set Nibble leaves Rails' own default, UTC, alone. It is the clock editors
  write against, what scheduled publishing goes by, and what the control panel shows dates in.
  **Upgrade:** set `time_zone` to keep the clock you had, or take UTC by leaving it out. Times already stored
  keep the instant they always were; what moves is the clock they are read and entered against.


## 0.14.1 — 2026-09-23 01:15 +0600

### What's fixed

- **`bin/ci` passes in a site whose content is files.** Nibble's own tests read the site's `content/` while
  running against their fixture schemas, so every page in it was measured against a blueprint that schema
  had never heard of and the suite fell over. Tests now read content of their own.
- **A page naming a blueprint the schema has not got is reported, not raised.** `nibble:build` names it the
  way it names a missing `id:`, so one page cannot take the whole index down.

### Changed

- **A release records the moment it was cut, not just the day.** A bare date carries no time zone, so
  anything reading the feed as UTC could date a release the day either side of the one it was cut on. The
  feed carries `released_at` alongside `date`, which stays the calendar day a site shows.


## 0.14.0 — 2026-09-23 00:56 +0600

### What's fixed

- **Re-running `nibble:install` no longer makes a site's own edits look like Nibble's.** Install recorded the
  site's current commit as the baseline `nibble:upgrade` and `nibble:check` compare against, so every file the
  site had touched since its last upgrade read as ours and changed in place. Only an upgrade moves that
  baseline now.
- **`nibble:build` no longer asks a build for secrets it cannot have.** It checked the master key, the mail
  credentials and the backup bucket — none of which exist while an image is being built — so the build failed
  on settings that only mean anything where the site runs. Those are checked at boot, where they can be true.

### Changed

- **Deploying scaffolds with `kamal init`, and Nibble changes only what is its own.** A site is a Rails
  application, so it gets Kamal's own config, secrets and hooks rather than copies Nibble maintained — the
  hooks in particular are Kamal's examples and were going stale in our tree. What Nibble writes over the top
  is what a Nibble site cannot do without: the storage volume its database lives in, `asset_path` covering
  the images published from `content/`, `SOLID_QUEUE_IN_PUMA`, and `SITE_URL`.


## 0.13.0 — 2026-09-23 00:17 +0600

> **Markdown served straight from its folder.** A collection written as files is read from the files themselves,
> with no database copy to keep in step.

### What's new

- **A folder of Markdown is served without a database copy of it.** Declare a collection with `files: docs`,
  give it a view, and the folder is the collection: its shape is the address, a folder's own `index.md` answers
  for the folder, and the folders are the navigation tree. Nothing is synced, nothing is migrated, and there is
  no step to remember on a deploy.
  - Each page declares an `id:` in its frontmatter, which is what links to it hold. Moving or renaming a file
    changes its address and keeps its identity; editing it changes neither.
  - Resolving one of these addresses is a lookup in memory rather than a query, so it is quicker than the rows
    it replaces. In development a file watcher rebuilds the index as you edit.
- **An image in a page is offered at the widths a browser can choose between.** Whether it was written beside
  the page or uploaded in the control panel, it renders with a `srcset` — so a phone stops fetching a
  screenshot meant for a desktop. `sizes` defaults to the full viewport, which is what a browser assumes
  anyway, and a theme narrows it in CSS where it knows the layout.
- **An image beside a page is published, not uploaded.** Write it next to the page, reference it as
  `![alt](diagram.png)`, and it is published under a digested name at `/nibble-assets/…` and served as a static
  file — cacheable forever, changing address only when the image itself changes. There is no upload step and
  nothing to keep in step. Only images are published, and a published file whose original has gone is removed.
- **`bin/rails nibble:build`** checks everything derived from files and generates what a build needs. It opens
  no database, so it runs in CI and in the image build — a page with no `id:`, unreadable frontmatter, a field
  no blueprint has, two pages claiming one id, or a page under a folder with no `index.md` all fail there
  rather than in a container. It checks the schema too — everything `nibble:check` does that needs no
  database.

### Changed

- **How a site builds and deploys is generated at install, not shipped.** `Dockerfile`, `.dockerignore`,
  `.kamal/secrets` and a `CLAUDE.md` stub are written once, alongside `config/deploy.yml`, and belong to the
  site from then on. They used to be Nibble's, which meant an upgrade merged over anything a site changed.
- **`NIBBLE-ARCHITECTURE.md` describes the CMS to whoever reads it**, an agent included: where the code lives,
  how a request becomes a page, what a site owns. It arrives with each release; the `CLAUDE.md` beside it is
  the site's and says so.
- **There is no staging environment.** Whether a site has one, what it is called and how it is protected are
  the site's to decide, so Nibble ships neither the environment, its deploy file, nor the basic auth that
  guarded it.
- **`asset_path` covers the whole of `public/`**, so images published from `content/` bridge a deploy the way
  Vite's bundles already did.

- **`files:` replaces `source:` on a collection**, and a collection written as files no longer has rows: no
  drafts, revisions, workflow, trash, content migrations or recorded redirects, none of which mean anything for
  a page whose truth is a file in git. Deleting the file is the whole of deleting the page.
- **`nibble:content:markdown` is gone**, and with it the sync on the boot path. `bin/docker-entrypoint` runs
  `nibble:upgrade` and nothing else, so a folder of files can no longer stop a container starting.
- A record cannot be saved onto an address a file already holds; it is refused where the save is made.

- **A theme no longer ships content.** A theme is layouts, views, components, styles and schema; content is a
  site's own. The example pages and posts a new install offers are Nibble's now, not the starter theme's, and
  the question `nibble:install` asks is unchanged.
- **`nibble:content:import` takes the directory to import.** It used to default to the active theme's
  `content/`, which is the assumption above in another form. A site keeps its package wherever it likes and
  names it.

### What's fixed

- **An image in Markdown is served at the field's preset.** `image_preset` was declared on the field, shown
  when editing it, and never reached the resolver — so an upload was rendered at whatever size it arrived at.
- **A page written as a file serves its words again.** The body of a Markdown file reached the theme as an
  empty string, so every file-backed page rendered its title and nothing else. It fills the field the
  blueprint writes as Markdown.

- **A command given a path that is not a content package says so in one line**, instead of printing a Ruby
  backtrace. Every `nibble:*` command now fails the same way.

### Upgrade

- **This release deletes files it used to ship and you now own.** `Dockerfile`, `.dockerignore`,
  `.kamal/secrets`, `.kamal/hooks/` and `CLAUDE.md` were ours and are now generated once at install, so the
  merge removes them from your checkout — without a conflict, because you had not changed them. **A hook you
  wrote yourself goes with them**, so check `.kamal/hooks/` before merging and keep a copy of anything real.
  Afterwards, `bin/rails nibble:install --only=deploy` writes the deploy files back and
  `bin/rails nibble:install` writes `CLAUDE.md`.
- **Your `config/deploy.yml` is left alone, so it keeps `asset_path: /rails/public/vite`.** Images published
  from `content/` live under `public/` too now, so widen it to `/rails/public` or a changed image's old
  address disappears mid-deploy.
- **A collection written as files needs `files:` where it said `source:`**, and every page needs an `id:` in
  its frontmatter. `bin/rails nibble:build` names every file that is missing one.

## 0.12.0 — 2026-09-22 19:33 +0600

### What's fixed

- **A site that removes or renames a collection can boot again.** An upgrade checks for drift before it runs
  content migrations and refuses to start on what it finds — but records left behind by a dropped collection
  were reported even when a pending migration existed to clear them. `delete_collection` is the answer to that
  very issue, so the only remedy was unreachable: the container could not start, and starting was what would
  have applied it. A pending migration now covers the issue it resolves, as it already did for a removed
  blueprint or field.

### What's new

- **`rename_collection`** is a content migration operation. A collection's handle is stored on every record, so
  renaming one in the schema stranded all of them with nothing available to bring them across. It carries the
  records over and re-indexes them for search. Addresses come from the route, so a rename moves nothing.


## 0.11.2 — 2026-09-22 17:14 +0600

### Changed

- **The update check reads `https://nibble.ink/api/v1/changelogs`.** The documentation site serves its release
  notes at `/changelogs`, and the feed behind them now answers on the matching address. The old
  `/api/v1/releases` still returns the identical feed, so an installation checks successfully either side of
  this release and nothing has to be upgraded in a particular order.
- **`Nibble::RELEASES_FEED` is now `Nibble::CHANGELOGS_FEED`.** The address and the constant that holds it say
  the same word. **Upgrade:** nothing to do unless one of your own files names the old constant, which only a
  site that reads it in `site/initializers/` or a check of its own would.

## 0.11.1 — 2026-09-22 07:07 +0600

### What's fixed

- **A browser that asks for AVIF no longer 500s on a transformed image.** libvips can report a format among the
  ones it reads without carrying the plugin that writes it — Debian splits AV1 encoding into its own package,
  so a stock image had every reason to believe it could produce AVIF and none to actually try. The AV1 encoder
  is now installed, and a format is only offered to a browser once it has genuinely been encoded, not merely
  found in the list of things libvips claims to support — so the same class of gap degrades to the next format
  instead of failing the request, on any build where an encoder turns out to be missing.

## 0.11.0 — 2026-09-22 06:43 +0600

### What's new

- **A folder of Markdown is synced when the container boots.** `bin/rails nibble:content:markdown` now runs
  beside `nibble:upgrade` before the server accepts a request, so merging a page publishes it and deleting one
  trashes it with no step to remember. The sync is idempotent, so a boot that changes nothing writes nothing.

### Changed

- **`nibble:content:markdown` over no collections is no longer an error.** Asked to sync every folder when a
  site has none, it now says so and exits cleanly. It used to exit non-zero, which — as of this release, where
  it runs at boot — would have stopped the container starting for every site that writes no Markdown.

## 0.10.1 — 2026-09-22 06:01 +0600

### What's fixed

- **A site no longer inherits Nibble's own local git excludes.** `bin/setup` hides the files Nibble generates
  but must never commit — `config/nibble.yml`, `config/deploy.yml`, `.nibble/`, the credentials, `db/schema.rb`
  — by writing them into `.git/info/exclude`. A site commits every one of those, so in a site the list was
  backwards: the files never appeared in `git status`, and a generated file left untracked is one a deploy
  builds without. A theme's generated `types.d.ts` went missing from the image this way, failing the build.
  `bin/setup` now leaves a site's excludes alone.

### Upgrade

- **If you installed before this release, clear the list once**: open `.git/info/exclude`, delete everything
  under `# Generated for this checkout`, then check what `git status` reveals. A theme's
  `.nibble/types.d.ts` in particular has to be committed — the production build reads it.

## 0.10.0 — 2026-09-22 05:40 +0600

### Changed

- **Uploads go to local storage until S3 is configured.** Production and staging named `:amazon` whatever the
  settings said, so a site with no bucket could not serve an upload at all. Name `AWS_BUCKET_NAME` and it is S3
  as before; leave it unset and files are stored on the server, under the volume a Kamal deploy already keeps.
  A site can now run before it has object storage.

### What's fixed

- **A folder of Markdown with a grid field no longer rewrites itself on every sync.** A grid row carries an id
  the control panel follows it by, a file carries none, and one was minted each time — so the page never looked
  unchanged, and every deploy wrote a revision, purged its cache and raised events for a page nobody had
  touched. The row ids already stored are now kept. The same applies to a replicator.

### Upgrade

- **If you run on S3 without setting `AWS_BUCKET_NAME`**, uploads were going to a bucket named
  `nibble-<environment>` by default. That default no longer selects S3 at all: without the variable this
  release stores files on the server instead, and anything already in that bucket stops being found. Set
  `AWS_BUCKET_NAME` before upgrading and nothing changes. A site that has never used S3 needs to do nothing.

## 0.9.1 — 2026-09-22 05:01 +0600

### What's fixed

- **A site's own content migrations no longer reach Nibble's tests.** The migration runner built its own list of
  schema layers and read the site's `schema/migrations/` directly, so adding a migration to a site made Nibble's
  suite fail in a site that had done nothing wrong. It now reads the layers the rest of the schema does.

## 0.9.0 — 2026-09-22 04:40 +0600

> **A public home.** The code is on GitHub, and the project lives at nibble.ink.

### What's new

- **A folder of Markdown decides its own addresses.** A collection written as files now answers where its files
  sit: `content/docs/index.md` is `/docs`, `content/docs/something.md` is `/docs/something`, and
  `content/docs/a/b.md` is `/docs/a/b`. Give the collection `route: /docs/{slug}` and a view, and that is the
  whole of it — nested pages no longer need `{parent_slugs}` spelled out, and a folder's own `index.md` no
  longer lands at `/docs/home`.
  A route that already places its pages — one naming `{parent_slugs}` or `{parent_uri}` — is left exactly as
  written.

### What's fixed

- **Changing where a collection lives now moves the pages already in it.** A route is not a file, so the
  Markdown sync had nothing to compare and reported no changes: the schema said one address and the database
  held another, with nothing reporting the difference. The next edit to a single page would then have moved
  that page on its own. The sync now treats a page whose address no longer matches its route as out of date,
  like any other difference between the folder and the site.

### Changed

- **Nibble has a public home.** The code is at `https://github.com/mah3uz/nibble.git`, and the project's site is
  at `https://nibble.ink`. `install.sh`, the README and the constants that say where releases come from all
  name them now.
- **The control panel reads the release notes from `https://nibble.ink/api/v1/releases`** rather than a raw file
  in a git repository. It serves the same notes, so nothing looks different; the address is one we can keep
  serving whatever happens to where the code is hosted.

### Upgrade

- **A Markdown collection routed `/x/{slug}` will see its nested pages move.** A page written at
  `content/x/a/b.md` answered at `/x/b` and now answers at `/x/a/b`, and a root `index.md` moves from `/x/home`
  to `/x`. The move happens on the next `bin/rails nibble:content:markdown`, and **no redirects are recorded
  for it** — if anything links to the old addresses, write the redirects yourself before running it. A
  collection whose route already names `{parent_slugs}` or `{parent_uri}` is unaffected.
- **This release moves where upgrades are fetched from, which the release before it cannot know.**
  `bin/nibble-upgrade` reads the address out of the version you already have, so the upgrade that takes you to
  this one still asks the old host. Run it once as
  `NIBBLE_REPO=https://github.com/mah3uz/nibble.git bin/nibble-upgrade`, and every upgrade after this one finds
  its own way.
- **A control panel older than this release keeps asking the old address for its notes**, so its update check
  quietly stops finding anything once that address goes. Upgrading is the fix; nothing else is affected.

## 0.8.0 — 2026-09-22 02:41 +0600

> **Feeds and landing pages.** A collection can have a feed and a landing page of its own, and a visitor's light or
> dark choice survives the first paint.

### What's new

- **A collection can have a landing page of its own.** Give it an `index_route`, and optionally an
  `index_template`, and that address renders the collection rather than one of its entries — the same pair
  taxonomies already had. A second single-entry collection carrying an index is no longer the way to do it.
- **A feed.** `feed: true` on a collection publishes it at `/feed-<handle>.xml`, everything that publishes one
  is merged into `/feed.xml`, and every page points at it so a reader finds it without being told. Atom, so
  dates need no interpreting. Set `feed: { title:, limit: }` to say more.
- **A visitor's light or dark choice survives the first paint.** The shell reads the `nibble_theme` cookie and
  writes `data-theme` on `<html>`, so a visitor who has chosen against their system preference no longer sees
  the other register flash before the page settles. A theme that writes that cookie needs no other change.
- **An entry's author reaches the theme**, as `author: { id, name }` on its props, loaded once for a whole
  listing rather than once per entry. Anyone who may edit a collection's entries can reassign it in the
  control panel.
- **A listing can sort by a blueprint field**, not only by a column, so a collection can be ordered by what it
  actually holds.
- **`{parent_slugs}` in a route.** A structured collection can now sit under a prefix of its own —
  `/docs{parent_slugs}/{slug}` — where `{parent_uri}` would have repeated the prefix at every level.
- **`position` can be set in frontmatter**, so a folder of Markdown can state its own order instead of
  depending on publication dates.
- **`delete_collection`** is a content migration operation. Renaming a collection used to leave its old records
  behind, reported by `nibble:check` with nothing available to clear them.

### What's fixed

- **The theme named in `config/nibble.yml` is the one that gets served.** The build compiled the theme the
  settings named while the page asked for the default theme's stylesheet, so a site with its own theme rendered
  its own markup with someone else's CSS and nothing said why. There was one way to resolve the active theme;
  now there is.
- **A folder of Markdown with an `index.md` at its root imports.** That file used to be refused for having no
  slug left, and the refusal discarded **every other page in the collection** along with it. It now becomes the
  collection's own root entry.
- **The page cache no longer outlives a local asset rebuild.** After `bin/vite build` the cached HTML went on
  naming hashed files that no longer existed until the process restarted. A deploy was never affected.
- **Nibble's own tests no longer assume the site around them is empty.** They took the site's schema, theme and
  routes as their own, so declaring a collection, bringing a theme or adding a route made Nibble's suite fail in
  a site that had done nothing wrong.

### Changed

- A theme that ships no `styles/theme.css` is served no stylesheet link, rather than being handed another
  theme's. A theme that has one whose build is missing still raises.
- `bin/ssr-smoke` proves the render for whatever theme is active, instead of looking for the default theme's
  404 copy.

### Upgrade

- **If you set `NIBBLE_THEME` to work around the theme being ignored, you can stop.** `config/nibble.yml`
  decides now, and the variable only overrides it. Where the two disagreed, the file wins — check they name the
  theme you meant before deploying.
- **If a folder of Markdown has an `index.md` at its root**, the next `bin/rails nibble:content:markdown`
  creates a page for it where it previously created nothing at all for that collection.

## 0.7.0 — 2026-09-21 21:39 +0600

> **A folder of Markdown is a collection.** Name a folder in a collection's schema, and the Markdown files in it are
> its pages.

### What's new

- **A collection can be written as Markdown files.** Name a folder inside `content/` in the collection's schema
  and `bin/rails nibble:content:markdown` makes the collection match it: a file is a page, a folder's `index.md`
  is the page its files sit under, frontmatter becomes fields, and a page whose file has gone is trashed. It is
  safe to run again, so a deploy can run it every time.
  - A link to another `.md` file becomes a link to that page, resolved when the page renders, so it survives
    either page moving. An image beside the pages becomes an asset, filed where it was written and uploaded
    again only when it changes.
  - The folders are a navigation tree, ordered by `order` in the frontmatter — the sidebar a documentation site
    needs, without maintaining one by hand.
  - Those pages are read-only in the control panel, and each one says which file it is written in and what to
    run after changing it.

### Changed

- `bin/nibble-release` offers the push rather than printing it, and offers to publish the feed in the repository
  it was written to. `--push` answers both without asking.

## 0.6.0 — 2026-09-21 20:32 +0600

### What's new

- A **markdown** fieldtype: write Markdown in any blueprint, with a preview rendered by the server so it shows
  what a theme will actually receive. Assets are referenced rather than linked, so replacing one does not leave
  documents pointing at the old file.
- Release notes in **Updates** are rendered rather than shown as Markdown source.
- **Code blocks are highlighted while you write them,** and carry the language you chose to the published page.
  A selector on the block names it, the control panel colours it as you type, and a theme highlights the page
  from the same name — Crumbs does, with the thirty-seven languages the selector offers, fetching only the ones
  a page actually uses.
- **Tab indents inside a code block,** two spaces at a time, and Shift-Tab takes them away. A selection spanning
  lines moves together.
- Writing in the control panel reads as prose: headings, quotes, tables, callouts and a code panel that looks
  like code, in both colour schemes.

### Changed

- **The documentation is no longer part of Nibble.** It is a site of its own, written in Markdown, which is also
  what publishes the release notes your control panel shows. Every site that installed Nibble was carrying a copy
  of our documentation and a feed file it never read from disk.
  **Upgrade:** taking this release deletes `docs/` from your tree. If you had put your own files there, git stops
  on the conflict — keep your side, or move them first.
- **The release feed moved with it, and is generated rather than appended to.** It is built from the changelog
  each time, so an entry corrected after its release now reaches every site instead of staying wrong.
  **Upgrade:** a control panel still on 0.5.0 asks for the feed at its old address, which this release removes,
  so its update check quietly fails until it upgrades. Upgrading is the fix; nothing else is affected.
- Choosing a term or an entry says **Choose…**, or whatever `placeholder` the field sets, rather than naming what
  the control is made of.

### What's fixed

- **A Markdown field with an image in it could not be imported.** Exporting wrote the asset's path where its id
  had been, and importing that file failed on the first slash, so content carrying one could not move between
  sites at all.
- Every field in a panel drew a hard line across its top in dark mode: an input's inset highlight, which belongs
  to an input standing on its own, painted inside the group that draws its border.
- Server rendering takes its port from `INERTIA_SSR_PORT` at both ends. A second instance — a test server beside
  a development one — fought the first for 13714, and the loser sat in a restart loop.

## 0.5.0 — 2026-09-21 03:34 +0600

### Changed

- **Everything of Nibble's now lives under `lib/nibble/`, and `app/` is yours.** Your models, controllers, jobs
  and views sit where a Rails application puts them, with nothing of ours beside them, and your views are looked
  in before Nibble's. Class names are unchanged.
  **Upgrade:** if you added files under `app/`, they stay exactly where they are and keep working. If you had
  changed one of Nibble's files in place — which `bin/rails nibble:check` reports — git will stop on it during the
  merge, because that file has moved.
- `bin/rails nibble:check` no longer reports files you added under a directory Nibble also uses as edits to ours.
  It reports what you changed or deleted of Nibble's, which is what an upgrade can actually stop on.
- `.github/` is gone. Workflows and dependency updates of ours have no business running in your repository,
  against your budget, on rules you did not write — and a site is a clone, so the only way not to send them is
  not to have them. `bin/ci` runs every check Nibble runs on itself. `.github/` is yours, empty or otherwise.
  **Upgrade:** taking this release deletes our copy from your tree. If you had put your own workflows there, git
  stops on the conflict — keep your side.

### What's new

- `site/test/` is yours for your own tests, run by `bin/ci` and by `bin/rails test site/test`, with Nibble's
  `test_helper` available. Nibble's own tests stay in `test/`.
- The README says how to send a change back rather than carry it, and states the ownership rule in one line.

## 0.4.0 — 2026-09-21 02:26 +0600

### What's new

- `bin/rails nibble:generate:view NAME --collection=posts` writes a view and its query sidecar into your own
  theme, typed for that collection's records, and says how to wire it up. It refuses to write into Nibble's
  theme, which is what `nibble:generate:theme` is for.

## 0.3.0 — 2026-09-21 02:20 +0600

### What's new

- `bin/rails nibble:generate:theme HANDLE` copies the starter theme into `themes/HANDLE`, names it as this site's
  theme and leaves ours alone, so a site never edits `themes/crumbs` to change how it looks.

### What's fixed

- The asset build ignored the theme named in `config/nibble.yml` and always bundled `themes/crumbs`, so a site
  with its own theme edited `.vue` files that were never built — silently, with nothing to see in any log. The
  build now resolves the theme the way the rest of Nibble does: your settings first, `NIBBLE_THEME` second.
- An upgrade stopped partway through on any site with its own theme or its own npm packages: `npm ci` refuses a
  lockfile that is not exactly ours.
- `nibble:generate:theme` registers the new theme with npm, so a later `npm ci` — in your own CI, or a container
  build — doesn't fail naming a workspace nothing told you about.
- A theme view that throws while rendering on the server now says which view and which URL in the log, instead of
  an anonymous stack trace. Vue drops only the piece that threw, so the page is otherwise served as normal.
- `bin/rails nibble:upgrade` writes `db/schema.rb` when there isn't one, so taking 0.2.1 — which stopped shipping
  ours — leaves a site with its own. **Upgrade:** 0.2.1 said to run `bin/rails db:prepare` for this; that only
  writes the file when there is something to migrate. If you have no `db/schema.rb`, run
  `bin/rails db:schema:dump` once, or take this release and it is written for you.

## 0.2.1 — 2026-09-21 01:10 +0600

### What's fixed

- The Updates screen showed only "Up to date" when you were already on the newest release, hiding every release's
  notes. It now lists them whatever version you are on, with the one you are running marked.

### Changed

- `package-lock.json` is shared, not ours alone: a site with its own theme or packages has to change it. An
  upgrade now rebuilds it with `npm install` rather than installing from it, so a merged lockfile repairs itself.
  **Upgrade:** if git reports a conflict on it, take either side and run `npm install` — the result is the same
  either way, and commit it.
- `db/schema.rb` is yours, and Nibble no longer ships one. It is generated from migrations, so two copies of it —
  ours and yours — conflicted on every upgrade that carried a migration, on a file neither of us edits by hand.
  **Upgrade:** the merge removes our copy. Run `bin/rails db:prepare` to regenerate yours, then commit it. If git
  reports a conflict on it instead, keep your side and run the same command.

## 0.2.0 — 2026-09-21 01:00 +0600

### What's new

- `bin/nibble-upgrade` takes this site to a release: it snapshots the database, gates on the incoming release's
  requirements, merges, installs dependencies and migrates. It runs on a workstation only.
- The upgrade offers to re-render the files you own that we generate, and reports what changed in our copy of
  anything you ejected.
- **Updates** in the sidebar: releases newer than the one you are running, what each one changed, and the command
  that takes it, with a count on the menu item that turns red when one of them is a security fix. A daily
  background check remembers the count; the page itself reads the file again when you open it, so no other page
  ever waits on it and there is nothing to set up. Nothing about your site is sent, and a switch on that screen
  stops the checks entirely.
- Settings a person changes in the control panel are kept in a `settings` table, separate from `config/nibble.yml`,
  which stays a file you edit by hand.

### Changed

- The first administrator is made by asking, not by environment variables: `bin/rails nibble:admin:create` asks
  for a name, email address and password, and refuses a password the rules reject. `ADMIN_EMAIL`,
  `ADMIN_PASSWORD` and `ADMIN_NAME` no longer do anything — `db:seed` seeds roles and tells you to run the
  command.
- `.nibble/install.yml` now records the answers the install was given, which is what lets an upgrade re-render
  your settings without asking again. Installs made before this keep working; the upgrade says it cannot
  re-render them.

## 0.1.0 — 2026-09-20 21:40 +0600

> **Content shaped by files.** Collections, blueprints and fieldtypes declared in YAML, entries checked against
> them, edited in a control panel and rendered on the server by a Vue theme.

### What's new

- `schema/` holds a site's own collections, blueprints, taxonomies, globals, navigation and forms. It is read after
  Nibble's and after the theme's, so a file here replaces one of ours whole.
- `site/` holds a site's control panel changes: `site/pages/<same path as ours>.vue` replaces one of our screens,
  `site/slots/{Logo,SidebarExtra,Scripts}.vue` replace parts of the chrome, and `site/initializers/*.rb` runs at
  boot.
- `bin/rails nibble:eject PATH` copies one of our files into `site/` and records it in `.nibble/ejected.yml`.
- `bin/rails nibble:check` reports ejected copies whose original has since changed, and files of ours edited in
  place rather than ejected.
- `bin/rails nibble:check --support` prints an install summary to paste into an issue.
- Load hooks `:nibble_entry`, `:nibble_term` and `:nibble_asset`, so a site adds behaviour without reopening our
  classes.
- `Gemfile.local` for a site's own gems.
- `config/nibble.yml` accepts `load_defaults`, which is how new behaviour gets turned on — never by upgrading.
- A licence: MIT (`LICENSE`). Use it, change it, sell it, rebrand the control panel; keep the copyright notice
  with copies. No warranty, no support promise.

### Changed

- Passwords must be at least 12 characters and mix lower case, upper case, a number and a symbol. The rule is on
  the model, so the control panel, password resets, invitations and the installer all apply it.
  **Upgrade:** existing passwords keep working; the rule applies the next time one is set. If you seed an
  administrator with `ADMIN_PASSWORD`, that value must now satisfy it.

- Every setting has a default in code, so `config/nibble.yml` can be absent or partial.
- Reserved paths are a floor a site adds to rather than a list it replaces: `/admin` can no longer be claimed by an
  entry.
- `config/routes.rb` belongs to the site. Nibble's routes are drawn before and after it.
- Nibble's migrations live in `lib/nibble/db/migrate`, leaving `db/migrate` and `db/schema.rb` to the site.

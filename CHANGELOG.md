# Changelog

What changed for a site running Nibble. Each release is a `##` heading, and inside it **What's new**, **What's
fixed**, **Changed** and **Security** are `###`.
Anything that needs you to act has an **Upgrade** note; releases without one are safe to take as they come. A
release whose database migrations cannot be undone says so in its entry, so you know the snapshot is the only way
back. The control panel shows these same notes, read from the feed the documentation site publishes, which is
generated from this file rather than written by hand.

Versions are ordered but not promises: while Nibble is `0.x`, anything can change between releases. Themes pin the
theme API (`nibble: '^1'` in `theme.yml`), not this number.

## Unreleased

### What's new

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

### What's fixed

- **Search snippets read as text,** not Markdown: `**`, links and image syntax no longer show around the match.
- **A page written as a file is indexed once.** Its words were stored twice, which ranked it above an entry saying
  the same thing.
- **A view that asks for `parent` type-checks.** The generated types picked it from the record, which has no such
  key, so `site/types.d.ts` failed to compile; it is typed as `ParentSummary` now.
- **A theme from `nibble:generate:theme` passes the format check,** starting with its `theme.yml`.
- **`nibble:check` no longer reports a sidebar taxonomy or the search toggle as removed.** Both are kept on an entry
  beside its blueprint, and the check only knew the blueprint's own fields.

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

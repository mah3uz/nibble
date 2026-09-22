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

- **A folder of Markdown is served without a database copy of it.** Declare a collection with `files: docs`,
  give it a view, and the folder is the collection: its shape is the address, a folder's own `index.md` answers
  for the folder, and the folders are the navigation tree. Nothing is synced, nothing is migrated, and there is
  no step to remember on a deploy.
  - Each page declares an `id:` in its frontmatter, which is what links to it hold. Moving or renaming a file
    changes its address and keeps its identity; editing it changes neither.
  - Resolving one of these addresses is a lookup in memory rather than a query, so it is quicker than the rows
    it replaces. In development a file watcher rebuilds the index as you edit.
- **`bin/rails nibble:build`** checks everything derived from files and generates what a build needs. It opens
  no database, so it runs in CI and in the image build — a page with no `id:`, unreadable frontmatter, a field
  no blueprint has, two pages claiming one id, or a page under a folder with no `index.md` all fail there
  rather than in a container.

### Changed

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

- **A command given a path that is not a content package says so in one line**, instead of printing a Ruby
  backtrace. Every `nibble:*` command now fails the same way.

## 0.12.0 — 2026-09-22

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


## 0.11.2 — 2026-09-22

### Changed

- **The update check reads `https://nibble.ink/api/v1/changelogs`.** The documentation site serves its release
  notes at `/changelogs`, and the feed behind them now answers on the matching address. The old
  `/api/v1/releases` still returns the identical feed, so an installation checks successfully either side of
  this release and nothing has to be upgraded in a particular order.
- **`Nibble::RELEASES_FEED` is now `Nibble::CHANGELOGS_FEED`.** The address and the constant that holds it say
  the same word. **Upgrade:** nothing to do unless one of your own files names the old constant, which only a
  site that reads it in `site/initializers/` or a check of its own would.

## 0.11.1 — 2026-09-22

### What's fixed

- **A browser that asks for AVIF no longer 500s on a transformed image.** libvips can report a format among the
  ones it reads without carrying the plugin that writes it — Debian splits AV1 encoding into its own package,
  so a stock image had every reason to believe it could produce AVIF and none to actually try. The AV1 encoder
  is now installed, and a format is only offered to a browser once it has genuinely been encoded, not merely
  found in the list of things libvips claims to support — so the same class of gap degrades to the next format
  instead of failing the request, on any build where an encoder turns out to be missing.

## 0.11.0 — 2026-09-22

### What's new

- **A folder of Markdown is synced when the container boots.** `bin/rails nibble:content:markdown` now runs
  beside `nibble:upgrade` before the server accepts a request, so merging a page publishes it and deleting one
  trashes it with no step to remember. The sync is idempotent, so a boot that changes nothing writes nothing.

### Changed

- **`nibble:content:markdown` over no collections is no longer an error.** Asked to sync every folder when a
  site has none, it now says so and exits cleanly. It used to exit non-zero, which — as of this release, where
  it runs at boot — would have stopped the container starting for every site that writes no Markdown.

## 0.10.1 — 2026-09-22

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

## 0.10.0 — 2026-09-22

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

## 0.9.1 — 2026-09-22

### What's fixed

- **A site's own content migrations no longer reach Nibble's tests.** The migration runner built its own list of
  schema layers and read the site's `schema/migrations/` directly, so adding a migration to a site made Nibble's
  suite fail in a site that had done nothing wrong. It now reads the layers the rest of the schema does.

## 0.9.0 — 2026-09-22

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

## 0.8.0 — 2026-09-22

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

## 0.7.0 — 2026-09-21

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

## 0.6.0 — 2026-09-21

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

## 0.5.0 — 2026-09-21

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

## 0.4.0 — 2026-09-21

### What's new

- `bin/rails nibble:generate:view NAME --collection=posts` writes a view and its query sidecar into your own
  theme, typed for that collection's records, and says how to wire it up. It refuses to write into Nibble's
  theme, which is what `nibble:generate:theme` is for.

## 0.3.0 — 2026-09-21

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

## 0.2.1 — 2026-09-21

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

## 0.2.0 — 2026-09-21

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

## 0.1.0 — 2026-09-20

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

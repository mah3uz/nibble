# Nibble's own files

Everything in this folder is Nibble's, and the next upgrade replaces it. Don't edit files here: an upgrade refuses to
run while one has been changed in place, and `nibble:check` reports it.

To change what Nibble does, use what the site owns:

- **Schema:** define the same handle in `site/schema/`, which is read after Nibble's and the theme's.
- **Theme:** start one of your own with `bin/rails nibble:generate:theme` and change it in `site/themes/`.
- **A Control Plane screen:** `bin/rails nibble:eject <path>` copies it to `site/cp/pages/`, where it replaces Nibble's.
- **Control Plane chrome:** components in `site/cp/slots/`.
- **Ruby:** the site's own `app/`, `config/initializers/` and `lib/`.

In development, the `where_is` tool of `bin/rails nibble:dev:mcp` says whose a file is and which of these applies.
How Nibble fits together is in [NIBBLE-ARCHITECTURE.md](NIBBLE-ARCHITECTURE.md).

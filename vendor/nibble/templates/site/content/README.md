# Your content, as files

This directory is yours, and it is where content lives as files rather than as rows. A collection whose pages are
written by hand names a folder in here:

```yaml
# site/schema/collections/docs.yml
files: docs      # the Markdown in site/content/docs
```

The folder is the collection. The site reads it when it starts, and in development whenever a file changes: a file
is a page, a folder's `index.md` is the page its files sit under, and frontmatter becomes fields. Every page needs an
`id:` that never changes. There is nothing to import and nothing to run on deploy.

`bin/rails nibble:build` checks every file against its blueprint without a database; `bin/ci` and the image build run
it.

Pages written this way are read-only in the control panel. The files are the source.

Nothing outside this directory can be named by `files:`, so a collection cannot read from the rest of the
application.

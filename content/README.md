# Your content, as files

This directory is yours, and it is where content lives as files rather than as rows. A collection whose pages are
written by hand names a folder in here:

```yaml
# schema/collections/docs.yml
source:
  markdown: docs      # the files in content/docs
  field: body         # the field their Markdown lands in
```

`bin/rails nibble:content:markdown` then makes that collection match the folder: a file is a page, a folder's
`index.md` is the page its files sit under, frontmatter becomes fields, and a page whose file has gone is
trashed. Run it whenever the files change — it is safe to run again, and a deploy is the usual place.

Pages written this way are read-only in the control panel. The files are the source, so editing them anywhere
else would only be overwritten.

Nothing outside this directory can be named as a source, so a collection cannot read from the rest of the
application.
